// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@fhenixprotocol/cofhe-contracts/FHE.sol";

interface IInvoiceVault {
    enum PoolTier { INSTITUTIONAL, GOVERNMENT, RETAIL }
    function getEncryptedAmount(uint256 tokenId) external view returns (euint128);
    function getEncryptedDueDate(uint256 tokenId) external view returns (euint128);
    function getEncryptedGovRef(uint256 tokenId) external view returns (euint128);
    function getPoolTier(uint256 tokenId) external view returns (PoolTier);
    function getInvoiceMeta(uint256 tokenId) external view returns (address submitter, uint256 submittedAt, bool active);
}

interface IBuyerOracle {
    function getEncryptedScore(bytes32 buyerKey) external view returns (euint8);
}

/// @title CreditOracle
/// @notice FHE credit scoring engine. Computes a risk score on encrypted invoice data
///         using range checks and FHE.select — no raw data exposed.
///         Wave 2: adds reputation scoring + government tier scoring.
contract CreditOracle {
    // ──────────────────────────────────────────────
    // State
    // ──────────────────────────────────────────────

    IInvoiceVault public immutable invoiceVault;
    address public owner;

    /// @notice Wave 2: FinancingPool address — authorized to call updateReputation
    address public financingPool;

    /// @notice Wave 3: External buyer verification oracle (optional)
    address public buyerOracle;

    // ──────────────────────────────────────────────
    // Pool-tier scoring constants
    // ──────────────────────────────────────────────

    /// @notice Institutional / GOVERNMENT max amount (1M USDC in 6-decimal units)
    uint128 public constant MAX_AMOUNT = 1_000_000 * 1e6;

    /// @notice Retail (freelancer) max amount (50K USDC)
    uint128 public constant MAX_AMOUNT_RETAIL = 50_000 * 1e6;

    /// @notice Minimum acceptable tenor: 7 days
    uint128 public constant MIN_TENOR_SECONDS = 7 days;

    /// @notice Score components — institutional / retail
    uint8 public constant SCORE_AMOUNT_OK  = 40;
    uint8 public constant SCORE_DUEDATE_OK = 35;
    uint8 public constant SCORE_BUYER_OK   = 25;

    /// @notice Wave 2: Government scoring constants
    ///         Base score 63 (amount + dueDate checks same weight) + gov bonus 37
    uint8 public constant SCORE_GOV_BONUS  = 37; // elevates score to 88–100 range
    /// @notice Known government entity reference hash (stored encrypted)
    ///         In production this is set by governance. Wave 2: owner sets it once.
    euint128 private knownGovRefHash;
    bool public govRefHashSet;

    // ──────────────────────────────────────────────
    // Scoring state
    // ──────────────────────────────────────────────

    /// @notice Token ID → encrypted score (pre-decryption)
    mapping(uint256 => euint8) private encryptedScores;

    /// @notice Token ID → plaintext score (post-decryption)
    mapping(uint256 => uint8) public scores;

    /// @notice Token ID → whether scoring has been requested
    mapping(uint256 => bool) public scoreRequested;

    /// @notice Token ID → whether plaintext score is available
    mapping(uint256 => bool) public scoreReady;

    // ──────────────────────────────────────────────
    // Wave 2: Reputation scoring state
    // ──────────────────────────────────────────────

    /// @notice Encrypted reputation score per borrower (never exposed directly)
    mapping(address => euint32) private reputationScores;

    /// @notice Number of successful repayments per borrower (plaintext counter)
    mapping(address => uint8) public repaymentCounts;

    // ──────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────

    event ScoreRequested(uint256 indexed tokenId);
    event ScoreFinalized(uint256 indexed tokenId, uint8 score);
    event ReputationUpdated(address indexed borrower, uint8 repaymentCount);
    event FinancingPoolUpdated(address indexed pool);
    event BuyerOracleUpdated(address indexed buyerOracle);
    event GovRefHashSet();

    // ──────────────────────────────────────────────
    // Modifiers
    // ──────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "CreditOracle: caller is not the owner");
        _;
    }

    modifier onlyFinancingPool() {
        require(msg.sender == financingPool, "CreditOracle: caller is not the financing pool");
        _;
    }

    // ──────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────

    constructor(address _invoiceVault) {
        require(_invoiceVault != address(0), "CreditOracle: zero address");
        invoiceVault = IInvoiceVault(_invoiceVault);
        owner = msg.sender;
    }

    // ──────────────────────────────────────────────
    // Admin
    // ──────────────────────────────────────────────

    /// @notice Wave 2: Set the FinancingPool address (called after FinancingPool is deployed)
    function setFinancingPool(address _financingPool) external onlyOwner {
        require(_financingPool != address(0), "CreditOracle: zero address");
        financingPool = _financingPool;
        emit FinancingPoolUpdated(_financingPool);
    }

    /// @notice Wave 3: Set external buyer verification oracle
    function setBuyerOracle(address _buyerOracle) external onlyOwner {
        require(_buyerOracle != address(0), "CreditOracle: zero address");
        buyerOracle = _buyerOracle;
        emit BuyerOracleUpdated(_buyerOracle);
    }

    /// @notice Wave 2: Set the known government entity reference hash (encrypted)
    ///         This is the FHE-encrypted value of the government contract prefix/ID
    ///         that valid government invoices must match.
    /// @param encryptedRef The encrypted government reference hash from cofhe/sdk
    function setGovRefHash(InEuint128 calldata encryptedRef) external onlyOwner {
        euint128 refHash = FHE.asEuint128(encryptedRef);
        FHE.allowThis(refHash);
        knownGovRefHash = refHash;
        govRefHashSet = true;
        emit GovRefHashSet();
    }

    // ──────────────────────────────────────────────
    // Scoring — Transaction 1: Compute + request decryption
    // ──────────────────────────────────────────────

    /// @notice Compute encrypted credit score for a token. Routes by PoolTier.
    ///         Triggers async decryption via FHE.allowPublic.
    /// @param tokenId The invoice token to score
    function requestScore(uint256 tokenId) external {
        require(!scoreRequested[tokenId], "CreditOracle: score already requested");

        (address submitter, , bool active) = invoiceVault.getInvoiceMeta(tokenId);
        require(submitter != address(0), "CreditOracle: invoice not found");
        require(active, "CreditOracle: invoice not active");

        IInvoiceVault.PoolTier tier = invoiceVault.getPoolTier(tokenId);
        euint8 totalScore;

        bytes32 buyerKey = keccak256(abi.encodePacked(tokenId));

        if (tier == IInvoiceVault.PoolTier.GOVERNMENT) {
            totalScore = _scoreGovernmentInvoice(tokenId);
        } else if (tier == IInvoiceVault.PoolTier.RETAIL) {
            totalScore = _scoreCorporateInvoice(tokenId, MAX_AMOUNT_RETAIL, buyerKey);
        } else {
            // INSTITUTIONAL (Wave 1 default)
            totalScore = _scoreCorporateInvoice(tokenId, MAX_AMOUNT, buyerKey);
        }

        encryptedScores[tokenId] = totalScore;
        FHE.allowThis(totalScore);
        FHE.allowPublic(totalScore);

        scoreRequested[tokenId] = true;
        emit ScoreRequested(tokenId);
    }

    /// @dev Score a corporate or retail invoice — range checks on amount + due date
    function _scoreCorporateInvoice(uint256 tokenId, uint128 maxAmount, bytes32 buyerKey) internal returns (euint8) {
        euint128 encAmount = invoiceVault.getEncryptedAmount(tokenId);
        euint128 encDueDate = invoiceVault.getEncryptedDueDate(tokenId);

        // ── Range Check 1: Amount ≤ maxAmount ──
        ebool amountInRange = FHE.lte(encAmount, FHE.asEuint128(maxAmount));
        euint8 amountScore = FHE.select(
            amountInRange,
            FHE.asEuint8(SCORE_AMOUNT_OK),
            FHE.asEuint8(0)
        );

        // ── Range Check 2: Due date ≥ (now + MIN_TENOR) ──
        uint128 minDueDate = uint128(block.timestamp) + MIN_TENOR_SECONDS;
        ebool dueDateOk = FHE.gte(encDueDate, FHE.asEuint128(minDueDate));
        euint8 dueDateScore = FHE.select(
            dueDateOk,
            FHE.asEuint8(SCORE_DUEDATE_OK),
            FHE.asEuint8(0)
        );

        // ── Wave 3: buyer verification from external oracle (fallback to mock if unset) ──
        euint8 buyerScore;
        if (buyerOracle == address(0)) {
            buyerScore = FHE.asEuint8(SCORE_BUYER_OK);
        } else {
            buyerScore = IBuyerOracle(buyerOracle).getEncryptedScore(buyerKey);
        }

        return FHE.add(FHE.add(amountScore, dueDateScore), buyerScore);
    }

    /// @dev Wave 2: Score a government invoice — FHE verifies gov ref against known entity hash
    ///      Government invoices score 88–100 (base 63 + gov bonus 37 if ref matches)
    function _scoreGovernmentInvoice(uint256 tokenId) internal returns (euint8) {
        euint128 encAmount = invoiceVault.getEncryptedAmount(tokenId);
        euint128 encDueDate = invoiceVault.getEncryptedDueDate(tokenId);
        euint128 encGovRef = invoiceVault.getEncryptedGovRef(tokenId);

        // ── Range Check 1: Amount (government max is same 1M tier) ──
        ebool amountInRange = FHE.lte(encAmount, FHE.asEuint128(MAX_AMOUNT));
        euint8 amountScore = FHE.select(
            amountInRange,
            FHE.asEuint8(SCORE_AMOUNT_OK),
            FHE.asEuint8(0)
        );

        // ── Range Check 2: Due date ──
        uint128 minDueDate = uint128(block.timestamp) + MIN_TENOR_SECONDS;
        ebool dueDateOk = FHE.gte(encDueDate, FHE.asEuint128(minDueDate));
        euint8 dueDateScore = FHE.select(
            dueDateOk,
            FHE.asEuint8(SCORE_DUEDATE_OK),
            FHE.asEuint8(0)
        );

        // ── Wave 2: FHE gov reference check ──
        // If knownGovRefHash has been set, verify encGovRef matches it.
        // If not set yet (testnet), fall back to buyer score so scoring still works.
        euint8 govBonusScore;
        if (govRefHashSet) {
            ebool govRefMatches = FHE.eq(encGovRef, knownGovRefHash);
            govBonusScore = FHE.select(
                govRefMatches,
                FHE.asEuint8(SCORE_BUYER_OK + SCORE_GOV_BONUS),
                FHE.asEuint8(SCORE_BUYER_OK)
            );
        } else {
            govBonusScore = FHE.asEuint8(SCORE_BUYER_OK + SCORE_GOV_BONUS);
        }

        return FHE.add(FHE.add(amountScore, dueDateScore), govBonusScore);
    }

    // ──────────────────────────────────────────────
    // Scoring — Transaction 2: Finalize (retrieve decrypted score)
    // ──────────────────────────────────────────────

    /// @notice Publish the decrypted score on-chain with proof, then finalize.
    ///         Call after requestScore. The frontend uses SDK decryptForTx to get
    ///         the plaintext + signature, then passes them here.
    /// @param tokenId The invoice token to finalize
    /// @param _decryptedScore The plaintext score from off-chain decryption
    /// @param _signature The Threshold Network signature proving correctness
    function finalizeScore(
        uint256 tokenId,
        uint8 _decryptedScore,
        bytes memory _signature
    ) external {
        require(scoreRequested[tokenId], "CreditOracle: score not requested");
        require(!scoreReady[tokenId], "CreditOracle: score already finalized");

        euint8 encScore = encryptedScores[tokenId];
        FHE.publishDecryptResult(encScore, _decryptedScore, _signature);

        scores[tokenId] = _decryptedScore;
        scoreReady[tokenId] = true;

        emit ScoreFinalized(tokenId, _decryptedScore);
    }

    // ──────────────────────────────────────────────
    // Wave 2: Reputation scoring
    // ──────────────────────────────────────────────

    /// @notice Called by FinancingPool on every successful repayment.
    ///         Increments plaintext repayment counter and adds to encrypted reputation.
    ///         Never exposes raw reputation score.
    /// @param borrower The SME/freelancer address that repaid
    function updateReputation(address borrower) external onlyFinancingPool {
        require(borrower != address(0), "CreditOracle: zero address");

        repaymentCounts[borrower]++;

        // Encrypted reputation accumulation — 10 points per repayment
        euint32 current = reputationScores[borrower];
        euint32 updated;
        if (euint32.unwrap(current) == 0) {
            // First repayment — initialize from zero
            updated = FHE.asEuint32(10);
        } else {
            updated = FHE.add(current, FHE.asEuint32(10));
        }
        FHE.allowThis(updated);
        reputationScores[borrower] = updated;

        emit ReputationUpdated(borrower, repaymentCounts[borrower]);
    }

    /// @notice Wave 2: Returns the advance rate tier based on repayment history.
    ///         Only the tier effect is readable — never the raw score.
    ///         Tier 90 unlocked after 3+ repayments.
    /// @param borrower The borrower address to check
    /// @return advanceRate 85 (default) or 90 (earned)
    function getAdvanceRateTier(address borrower) external view returns (uint8) {
        if (repaymentCounts[borrower] >= 3) return 90;
        return 85;
    }

    // ──────────────────────────────────────────────
    // Read functions
    // ──────────────────────────────────────────────

    /// @notice Get the credit score for a token (reverts if not ready)
    function getScore(uint256 tokenId) external view returns (uint8) {
        require(scoreReady[tokenId], "CreditOracle: score not available");
        return scores[tokenId];
    }

    /// @notice Get the ciphertext handle (ctHash) of the encrypted score.
    ///         Used by the frontend to call decryptForTx before finalizeScore.
    function getEncryptedScoreHandle(uint256 tokenId) external view returns (bytes32) {
        require(scoreRequested[tokenId], "CreditOracle: score not requested");
        return euint8.unwrap(encryptedScores[tokenId]);
    }

    /// @notice Check if the score is ready to read
    function isScoreReady(uint256 tokenId) external view returns (bool) {
        return scoreReady[tokenId];
    }

    /// @notice Transfer ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "CreditOracle: zero address");
        owner = newOwner;
    }
}
