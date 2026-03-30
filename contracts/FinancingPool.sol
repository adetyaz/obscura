// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

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
}

/// @title FinancingPool
/// @notice Handles invoice funding, escrow, repayment, and settlement.
///         Advance amount and lender yield are computed in FHE encrypted space.
contract FinancingPool {
    // ──────────────────────────────────────────────
    // State
    // ──────────────────────────────────────────────

    IInvoiceVaultFP public immutable invoiceVault;
    ICreditOracle public immutable creditOracle;
    address public owner;

    /// @notice Basis-point denominator (100% = 10_000)
    uint128 public constant BPS = 10_000;

    struct Position {
        uint256 tokenId;
        address lender;
        address sme;
        uint16 advanceRateBps;      // e.g. 8500 = 85%
        uint16 discountRateBps;     // e.g. 200 = 2%
        uint256 fundedAt;
        bool settled;
        // Encrypted fields — computed on funding
        euint128 encAdvanceAmount;  // amount * advanceRate / BPS
        euint128 encFeeAmount;      // amount * discountRate / BPS
        euint128 encRepayAmount;    // advanceAmount + feeAmount
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
    mapping(uint256 => uint128) public repayAmountPlain; // decrypted repay amount

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
    ///         Advance and fee amounts are computed in FHE encrypted space.
    /// @param tokenId       The invoice token to fund
    /// @param advanceRateBps Advance rate in basis points (e.g. 8500 = 85%)
    /// @param discountRateBps Discount/fee rate in basis points (e.g. 200 = 2%)
    function fundInvoice(
        uint256 tokenId,
        uint16 advanceRateBps,
        uint16 discountRateBps
    ) external {
        require(!isFunded[tokenId], "FinancingPool: already funded");
        require(advanceRateBps > 0 && advanceRateBps <= BPS, "FinancingPool: invalid advance rate");
        require(discountRateBps > 0 && discountRateBps <= BPS, "FinancingPool: invalid discount rate");

        // Verify invoice is active and scored
        (address submitter, , bool active) = invoiceVault.getInvoiceMeta(tokenId);
        require(submitter != address(0), "FinancingPool: invoice not found");
        require(active, "FinancingPool: invoice not active");
        require(creditOracle.isScoreReady(tokenId), "FinancingPool: score not ready");
        require(msg.sender != submitter, "FinancingPool: cannot fund own invoice");

        // Transfer token from SME to this contract (escrow)
        // Requires SME to have approved or the InvoiceVault owner to authorize
        invoiceVault.safeTransferFrom(submitter, address(this), tokenId, 1, "");

        // ── FHE computation: advance and fee amounts ──
        euint128 encAmount = invoiceVault.getEncryptedAmount(tokenId);

        // advanceAmount = encAmount * advanceRateBps / BPS
        euint128 encAdvance = FHE.div(
            FHE.mul(encAmount, FHE.asEuint128(uint128(advanceRateBps))),
            FHE.asEuint128(BPS)
        );

        // feeAmount = encAmount * discountRateBps / BPS
        euint128 encFee = FHE.div(
            FHE.mul(encAmount, FHE.asEuint128(uint128(discountRateBps))),
            FHE.asEuint128(BPS)
        );

        // repayAmount = advanceAmount + feeAmount
        euint128 encRepay = FHE.add(encAdvance, encFee);

        // FHE access: allow this contract to read the computed values
        FHE.allowThis(encAdvance);
        FHE.allowThis(encFee);
        FHE.allowThis(encRepay);

        // Allow the SME to see their repay obligation
        FHE.allow(encRepay, submitter);
        FHE.allow(encAdvance, submitter);

        // Allow the lender to see their advance & fee
        FHE.allow(encAdvance, msg.sender);
        FHE.allow(encFee, msg.sender);

        // Store position
        positions[tokenId] = Position({
            tokenId: tokenId,
            lender: msg.sender,
            sme: submitter,
            advanceRateBps: advanceRateBps,
            discountRateBps: discountRateBps,
            fundedAt: block.timestamp,
            settled: false,
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

        // Request async decryption of repay amount
        FHE.decrypt(pos.encRepayAmount);
        settlementRequested[tokenId] = true;
    }

    // ──────────────────────────────────────────────
    // Repayment — Step 2: Finalize settlement (after decryption completes)
    // ──────────────────────────────────────────────

    /// @notice Finalize settlement — retrieves decrypted repay amount and stores it.
    ///         Call after requestSettlement in a separate transaction.
    /// @param tokenId The funded invoice token
    function finalizeSettlement(uint256 tokenId) external {
        require(settlementRequested[tokenId], "FinancingPool: settlement not requested");
        require(!settlementReady[tokenId], "FinancingPool: already finalized");

        Position storage pos = positions[tokenId];

        (uint128 plainRepay, bool isDecrypted) = FHE.getDecryptResultSafe(pos.encRepayAmount);
        require(isDecrypted, "FinancingPool: decryption not ready");

        repayAmountPlain[tokenId] = plainRepay;
        settlementReady[tokenId] = true;
    }

    // ──────────────────────────────────────────────
    // Repayment — Step 3: SME sends repayment, contract settles
    // ──────────────────────────────────────────────

    /// @notice SME sends repayment. Contract settles the position:
    ///         lender receives principal + fee, token is burned.
    /// @param tokenId The funded invoice token
    function repay(uint256 tokenId) external payable {
        require(isFunded[tokenId], "FinancingPool: not funded");
        require(settlementReady[tokenId], "FinancingPool: settlement not finalized");

        Position storage pos = positions[tokenId];
        require(!pos.settled, "FinancingPool: already settled");
        require(msg.sender == pos.sme, "FinancingPool: only SME can repay");

        uint128 repayAmount = repayAmountPlain[tokenId];
        require(msg.value >= repayAmount, "FinancingPool: insufficient repayment");

        // Transfer repayment to lender
        (bool sent, ) = pos.lender.call{value: repayAmount}("");
        require(sent, "FinancingPool: lender transfer failed");

        // Refund excess
        uint256 excess = msg.value - repayAmount;
        if (excess > 0) {
            (bool refunded, ) = msg.sender.call{value: excess}("");
            require(refunded, "FinancingPool: refund failed");
        }

        // Burn the escrowed token
        invoiceVault.burn(address(this), tokenId, 1);

        pos.settled = true;

        emit RepaymentReceived(tokenId, msg.sender, repayAmount);
        emit PositionSettled(tokenId, pos.lender, pos.sme);
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
            bool settled
        )
    {
        Position storage pos = positions[tokenId];
        return (
            pos.lender,
            pos.sme,
            pos.advanceRateBps,
            pos.discountRateBps,
            pos.fundedAt,
            pos.settled
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
