// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@fhenixprotocol/cofhe-contracts/FHE.sol";

interface IInvoiceVaultFP {
    function getInvoiceMeta(uint256 tokenId)
        external
        view
        returns (address submitter, uint256 submittedAt, bool active);

    function getEncryptedAmount(uint256 tokenId)
        external
        view
        returns (euint128);

    function balanceOf(address account, uint256 id)
        external
        view
        returns (uint256);

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    function burn(address account, uint256 id, uint256 amount) external;
}

interface ICreditOracle {
    function isScoreReady(uint256 tokenId) external view returns (bool);
    function getScore(uint256 tokenId) external view returns (uint8);
    function updateReputation(address borrower) external;
}

/// @title FinancingPool
/// @notice Handles invoice funding, escrow, repayment, and settlement.
///         Wave 1: advance amounts and lender yield computed in FHE encrypted space.
///         Wave 2: adds grace period, default escalation, and reputation updates on repayment.
contract FinancingPool {
    // ──────────────────────────────────────────────
    // Wave 2: Position status enum
    // ──────────────────────────────────────────────

    enum PositionStatus { ACTIVE, REPAID, GRACE, ESCALATED }

    // ──────────────────────────────────────────────
    // State
    // ──────────────────────────────────────────────

    IInvoiceVaultFP public immutable invoiceVault;
    ICreditOracle public immutable creditOracle;
    address public owner;

    /// @notice Basis-point denominator (100% = 10_000)
    uint128 public constant BPS = 10_000;

    /// @notice Wave 2: Grace period before escalation is allowed
    uint256 public constant GRACE_PERIOD = 14 days;

    struct Position {
        uint256 tokenId;
        address lender;
        address sme;
        uint16 advanceRateBps;
        uint16 discountRateBps;
        uint256 fundedAt;
        uint256 maturityDate;       // Wave 2: plaintext maturity (tenor days from fundedAt)
        uint256 gracePeriodEnd;     // Wave 2: gracePeriodEnd = maturityDate + GRACE_PERIOD
        bool settled;
        PositionStatus status;      // Wave 2: lifecycle status
        // Encrypted fields — computed on funding
        euint128 encAdvanceAmount;
        euint128 encFeeAmount;
        euint128 encRepayAmount;
    }

    /// @notice Token ID → Position
    mapping(uint256 => Position) public positions;

    /// @notice Token ID → whether it has been funded
    mapping(uint256 => bool) public isFunded;

    /// @notice Lender → list of token IDs they funded
    mapping(address => uint256[]) private lenderPositions;

    // ──────────────────────────────────────────────
    // Settlement state (async decryption)
    // ──────────────────────────────────────────────

    mapping(uint256 => bool) public settlementRequested;
    mapping(uint256 => bool) public settlementReady;
    mapping(uint256 => uint128) public repayAmountPlain;

    // ──────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────

    event InvoiceFunded(
        uint256 indexed tokenId,
        address indexed lender,
        address indexed smeAddress,
        uint16 advanceRateBps,
        uint16 discountRateBps
    );

    event RepaymentReceived(uint256 indexed tokenId, address indexed sme, uint256 amount);

    event PositionSettled(
        uint256 indexed tokenId,
        address indexed lender,
        address indexed sme
    );

    /// @notice Wave 2: Emitted when a position enters grace period
    event GracePeriodStarted(uint256 indexed tokenId, uint256 gracePeriodEnd);

    /// @notice Wave 2: Emitted when lender triggers escalation after grace expires
    event EscalationTriggered(uint256 indexed tokenId, address indexed lender, address indexed borrower);

    // ──────────────────────────────────────────────
    // Modifiers
    // ──────────────────────────────────────────────

    modifier onlyOwner() {
        require(msg.sender == owner, "FinancingPool: caller is not the owner");
        _;
    }

    // ──────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────

    constructor(address _invoiceVault, address _creditOracle) {
        require(_invoiceVault != address(0), "FinancingPool: zero vault address");
        require(_creditOracle != address(0), "FinancingPool: zero oracle address");
        invoiceVault = IInvoiceVaultFP(_invoiceVault);
        creditOracle = ICreditOracle(_creditOracle);
        owner = msg.sender;
    }

    // ──────────────────────────────────────────────
    // Funding
    // ──────────────────────────────────────────────

    /// @notice Lender funds an invoice. Token is locked in escrow.
    ///         Wave 2: accepts a tenorDays param to set maturity + grace period end.
    /// @param tokenId         The invoice token to fund
    /// @param advanceRateBps  Advance rate in basis points (e.g. 8500 = 85%)
    /// @param discountRateBps Discount/fee rate in basis points (e.g. 200 = 2%)
    /// @param tenorDays       Repayment tenor in days (used to compute maturity date)
    function fundInvoice(
        uint256 tokenId,
        uint16 advanceRateBps,
        uint16 discountRateBps,
        uint16 tenorDays
    ) external {
        require(!isFunded[tokenId], "FinancingPool: already funded");
        require(advanceRateBps > 0 && advanceRateBps <= BPS, "FinancingPool: invalid advance rate");
        require(discountRateBps > 0 && discountRateBps <= BPS, "FinancingPool: invalid discount rate");
        require(tenorDays > 0 && tenorDays <= 365, "FinancingPool: invalid tenor");

        (address submitter, , bool active) = invoiceVault.getInvoiceMeta(tokenId);
        require(submitter != address(0), "FinancingPool: invoice not found");
        require(active, "FinancingPool: invoice not active");
        require(creditOracle.isScoreReady(tokenId), "FinancingPool: score not ready");
        require(msg.sender != submitter, "FinancingPool: cannot fund own invoice");

        invoiceVault.safeTransferFrom(submitter, address(this), tokenId, 1, "");

        euint128 encAmount = invoiceVault.getEncryptedAmount(tokenId);

        euint128 encAdvance = FHE.div(
            FHE.mul(encAmount, FHE.asEuint128(uint128(advanceRateBps))),
            FHE.asEuint128(BPS)
        );

        euint128 encFee = FHE.div(
            FHE.mul(encAmount, FHE.asEuint128(uint128(discountRateBps))),
            FHE.asEuint128(BPS)
        );

        euint128 encRepay = FHE.add(encAdvance, encFee);

        FHE.allowThis(encAdvance);
        FHE.allowThis(encFee);
        FHE.allowThis(encRepay);
        FHE.allow(encRepay, submitter);
        FHE.allow(encAdvance, submitter);
        FHE.allow(encAdvance, msg.sender);
        FHE.allow(encFee, msg.sender);

        uint256 maturity = block.timestamp + (uint256(tenorDays) * 1 days);

        positions[tokenId] = Position({
            tokenId: tokenId,
            lender: msg.sender,
            sme: submitter,
            advanceRateBps: advanceRateBps,
            discountRateBps: discountRateBps,
            fundedAt: block.timestamp,
            maturityDate: maturity,
            gracePeriodEnd: maturity + GRACE_PERIOD,
            settled: false,
            status: PositionStatus.ACTIVE,
            encAdvanceAmount: encAdvance,
            encFeeAmount: encFee,
            encRepayAmount: encRepay
        });

        isFunded[tokenId] = true;
        lenderPositions[msg.sender].push(tokenId);

        emit InvoiceFunded(tokenId, msg.sender, submitter, advanceRateBps, discountRateBps);
    }

    // ──────────────────────────────────────────────
    // Repayment — Step 1: SME triggers repayment + async decryption
    // ──────────────────────────────────────────────

    /// @notice SME initiates repayment. Triggers async decryption of the repay amount.
    /// @param tokenId The funded invoice token
    function requestSettlement(uint256 tokenId) external {
        require(isFunded[tokenId], "FinancingPool: not funded");
        Position storage pos = positions[tokenId];
        require(!pos.settled, "FinancingPool: already settled");
        require(msg.sender == pos.sme, "FinancingPool: only SME can repay");
        require(!settlementRequested[tokenId], "FinancingPool: settlement already requested");

        FHE.allowPublic(pos.encRepayAmount);
        settlementRequested[tokenId] = true;
    }

    // ──────────────────────────────────────────────
    // Repayment — Step 2: Finalize settlement (after decryption completes)
    // ──────────────────────────────────────────────

    /// @notice Finalize settlement — publish decrypted repay amount with proof.
    function finalizeSettlement(
        uint256 tokenId,
        uint128 _decryptedRepay,
        bytes memory _signature
    ) external {
        require(settlementRequested[tokenId], "FinancingPool: settlement not requested");
        require(!settlementReady[tokenId], "FinancingPool: already finalized");

        Position storage pos = positions[tokenId];
        FHE.publishDecryptResult(pos.encRepayAmount, _decryptedRepay, _signature);

        repayAmountPlain[tokenId] = _decryptedRepay;
        settlementReady[tokenId] = true;
    }

    // ──────────────────────────────────────────────
    // Repayment — Step 3: SME sends repayment, contract settles
    // ──────────────────────────────────────────────

    /// @notice SME sends repayment. Contract settles the position and updates reputation.
    function repay(uint256 tokenId) external payable {
        require(isFunded[tokenId], "FinancingPool: not funded");
        require(settlementReady[tokenId], "FinancingPool: settlement not finalized");

        Position storage pos = positions[tokenId];
        require(!pos.settled, "FinancingPool: already settled");
        require(msg.sender == pos.sme, "FinancingPool: only SME can repay");

        uint128 repayAmount = repayAmountPlain[tokenId];
        require(msg.value >= repayAmount, "FinancingPool: insufficient repayment");

        (bool sent, ) = pos.lender.call{value: repayAmount}("");
        require(sent, "FinancingPool: lender transfer failed");

        uint256 excess = msg.value - repayAmount;
        if (excess > 0) {
            (bool refunded, ) = msg.sender.call{value: excess}("");
            require(refunded, "FinancingPool: refund failed");
        }

        invoiceVault.burn(address(this), tokenId, 1);

        pos.settled = true;
        pos.status = PositionStatus.REPAID;

        // Wave 2: update encrypted reputation on successful repayment
        creditOracle.updateReputation(pos.sme);

        emit RepaymentReceived(tokenId, msg.sender, repayAmount);
        emit PositionSettled(tokenId, pos.lender, pos.sme);
    }

    // ──────────────────────────────────────────────
    // Wave 2: Grace period + escalation
    // ──────────────────────────────────────────────

    /// @notice Wave 2: Callable by anyone after maturity to open the grace period.
    ///         Transitions position from ACTIVE to GRACE.
    /// @param tokenId The funded invoice token
    function enterGracePeriod(uint256 tokenId) external {
        require(isFunded[tokenId], "FinancingPool: not funded");
        Position storage pos = positions[tokenId];
        require(!pos.settled, "FinancingPool: already settled");
        require(pos.status == PositionStatus.ACTIVE, "FinancingPool: not active");
        require(block.timestamp > pos.maturityDate, "FinancingPool: maturity not reached");

        pos.status = PositionStatus.GRACE;
        emit GracePeriodStarted(tokenId, pos.gracePeriodEnd);
    }

    /// @notice Wave 2: Lender triggers escalation after grace period expires.
    ///         Emits EscalationTriggered. Frontend listens and calls decryptForTx
    ///         to obtain buyer identity + invoice amount for legal recovery.
    ///         No admin can force-settle — only lender, only after grace expires.
    /// @param tokenId The funded invoice token
    function triggerEscalation(uint256 tokenId) external {
        require(isFunded[tokenId], "FinancingPool: not funded");
        Position storage pos = positions[tokenId];
        require(msg.sender == pos.lender, "FinancingPool: only lender can escalate");
        require(pos.status == PositionStatus.GRACE, "FinancingPool: not in grace period");
        require(block.timestamp > pos.gracePeriodEnd, "FinancingPool: grace period still active");

        pos.status = PositionStatus.ESCALATED;

        emit EscalationTriggered(tokenId, pos.lender, pos.sme);
    }

    // ──────────────────────────────────────────────
    // Read functions
    // ──────────────────────────────────────────────

    /// @notice Get all token IDs funded by a lender
    function getLenderPositions(address lender) external view returns (uint256[] memory) {
        return lenderPositions[lender];
    }

    /// @notice Get position details (non-encrypted fields)
    function getPositionMeta(uint256 tokenId)
        external
        view
        returns (
            address lender,
            address sme,
            uint16 advanceRateBps,
            uint16 discountRateBps,
            uint256 fundedAt,
            uint256 maturityDate,
            uint256 gracePeriodEnd,
            bool settled,
            PositionStatus status
        )
    {
        Position storage pos = positions[tokenId];
        return (
            pos.lender,
            pos.sme,
            pos.advanceRateBps,
            pos.discountRateBps,
            pos.fundedAt,
            pos.maturityDate,
            pos.gracePeriodEnd,
            pos.settled,
            pos.status
        );
    }

    /// @notice Get encrypted advance amount handle (caller must have FHE access)
    function getEncryptedAdvance(uint256 tokenId) external view returns (euint128) {
        return positions[tokenId].encAdvanceAmount;
    }

    /// @notice Get encrypted fee amount handle (caller must have FHE access)
    function getEncryptedFee(uint256 tokenId) external view returns (euint128) {
        return positions[tokenId].encFeeAmount;
    }

    /// @notice Get encrypted repay amount handle (caller must have FHE access)
    function getEncryptedRepay(uint256 tokenId) external view returns (euint128) {
        return positions[tokenId].encRepayAmount;
    }

    /// @notice Get the plaintext repay amount (only available after finalizeSettlement)
    function getRepayAmount(uint256 tokenId) external view returns (uint128) {
        require(settlementReady[tokenId], "FinancingPool: repay amount not decrypted");
        return repayAmountPlain[tokenId];
    }

    /// @notice Transfer ownership
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "FinancingPool: zero address");
        owner = newOwner;
    }

    /// @notice Allow contract to receive ETH (for repayments)
    receive() external payable {}
}
