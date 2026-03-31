// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@fhenixprotocol/cofhe-contracts/FHE.sol";

interface IInvoiceVault {
    function getEncryptedAmount(uint256 tokenId) external view returns (euint128);
    function getEncryptedDueDate(uint256 tokenId) external view returns (euint128);
    function getInvoiceMeta(uint256 tokenId) external view returns (address submitter, uint256 submittedAt, bool active);
}

/// @title CreditOracle
/// @notice FHE credit scoring engine. Computes a risk score on encrypted invoice data
///         using range checks and FHE.select — no raw data exposed.
contract CreditOracle {
    // ──────────────────────────────────────────────
    // State
    // ──────────────────────────────────────────────

    IInvoiceVault public immutable invoiceVault;
    address public owner;

    /// @notice Maximum acceptable invoice amount (1M USDC in 6-decimal units)
    uint128 public constant MAX_AMOUNT = 1_000_000 * 1e6;

    /// @notice Minimum acceptable tenor: 7 days from now (approx, checked at scoring time)
    uint128 public constant MIN_TENOR_SECONDS = 7 days;

    /// @notice Score components
    uint8 public constant SCORE_AMOUNT_OK = 40;
    uint8 public constant SCORE_DUEDATE_OK = 35;
    uint8 public constant SCORE_BUYER_OK = 25; // Mock buyer check — always passes in Wave 1

    /// @notice Token ID → encrypted score (pre-decryption)
    mapping(uint256 => euint8) private encryptedScores;

    /// @notice Token ID → plaintext score (post-decryption)
    mapping(uint256 => uint8) public scores;

    /// @notice Token ID → whether scoring has been requested
    mapping(uint256 => bool) public scoreRequested;

    /// @notice Token ID → whether plaintext score is available
    mapping(uint256 => bool) public scoreReady;

    // ──────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────

    event ScoreRequested(uint256 indexed tokenId);
    event ScoreFinalized(uint256 indexed tokenId, uint8 score);

    // ──────────────────────────────────────────────
    // Modifiers
    // ──────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "CreditOracle: caller is not the owner");
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
    // Scoring — Transaction 1: Compute + request decryption
    // ──────────────────────────────────────────────

    /// @notice Compute encrypted credit score for a token. Triggers async decryption.
    /// @param tokenId The invoice token to score
    function requestScore(uint256 tokenId) external {
        require(!scoreRequested[tokenId], "CreditOracle: score already requested");

        // Verify invoice exists and is active
        (address submitter, , bool active) = invoiceVault.getInvoiceMeta(tokenId);
        require(submitter != address(0), "CreditOracle: invoice not found");
        require(active, "CreditOracle: invoice not active");

        // Read encrypted fields — CreditOracle must have been granted FHE access
        euint128 encAmount = invoiceVault.getEncryptedAmount(tokenId);
        euint128 encDueDate = invoiceVault.getEncryptedDueDate(tokenId);

        // ── FHE Range Check 1: Amount ≤ MAX_AMOUNT ──
        ebool amountInRange = FHE.lte(encAmount, FHE.asEuint128(MAX_AMOUNT));
        euint8 amountScore = FHE.select(
            amountInRange,
            FHE.asEuint8(SCORE_AMOUNT_OK),
            FHE.asEuint8(0)
        );

        // ── FHE Range Check 2: Due date ≥ (now + MIN_TENOR) ──
        uint128 minDueDate = uint128(block.timestamp) + MIN_TENOR_SECONDS;
        ebool dueDateOk = FHE.gte(encDueDate, FHE.asEuint128(minDueDate));
        euint8 dueDateScore = FHE.select(
            dueDateOk,
            FHE.asEuint8(SCORE_DUEDATE_OK),
            FHE.asEuint8(0)
        );

        // ── Mock buyer check — always passes in Wave 1 ──
        euint8 buyerScore = FHE.asEuint8(SCORE_BUYER_OK);

        // ── Total score (0–100) ──
        euint8 totalScore = FHE.add(FHE.add(amountScore, dueDateScore), buyerScore);

        // Store the encrypted score
        encryptedScores[tokenId] = totalScore;
        FHE.allowThis(totalScore);

        // Mark as publicly decryptable (off-chain SDK fetches plaintext + signature)
        FHE.allowPublic(totalScore);

        scoreRequested[tokenId] = true;
        emit ScoreRequested(tokenId);
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

        // Verify and publish — reverts if signature is invalid
        FHE.publishDecryptResult(encScore, _decryptedScore, _signature);

        scores[tokenId] = _decryptedScore;
        scoreReady[tokenId] = true;

        emit ScoreFinalized(tokenId, _decryptedScore);
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
