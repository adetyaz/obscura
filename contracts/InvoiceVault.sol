// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@fhenixprotocol/cofhe-contracts/FHE.sol";

interface ICredentialRegistry {
    enum CredentialType { NONE, KYB, KYC_INDIVIDUAL }
    function isVerified(address wallet) external view returns (bool);
    function isVerifiedKYB(address wallet) external view returns (bool);
    function isVerifiedKYC(address wallet) external view returns (bool);
}

/// @title InvoiceVault
/// @notice Accepts encrypted invoice data, stores it, and mints ERC-1155 tokens.
///         Wave 1: corporate invoices (KYB required).
///         Wave 2: government invoices (KYB + gov ref), freelancer invoices (KYC_INDIVIDUAL).
contract InvoiceVault {
    // ──────────────────────────────────────────────
    // Wave 2: Pool tier enum
    // ──────────────────────────────────────────────

    enum PoolTier { INSTITUTIONAL, GOVERNMENT, RETAIL }

    // ──────────────────────────────────────────────
    // State
    // ──────────────────────────────────────────────

    ICredentialRegistry public immutable credentialRegistry;
    address public owner;
    address public creditOracle;
    address public financingPool;

    uint256 public nextTokenId = 1;

    struct Invoice {
        address submitter;
        euint128 encryptedAmount;
        euint128 encryptedDueDate;
        bytes encryptedBuyer;
        euint128 encryptedGovRef;   // Wave 2: government contract reference (zero for non-gov)
        PoolTier tier;               // Wave 2: pool tier classification
        uint256 submittedAt;
        bool active;
    }

    /// @notice Token ID → Invoice data
    mapping(uint256 => Invoice) private invoices;

    /// @notice Wallet → list of token IDs they submitted
    mapping(address => uint256[]) private userInvoices;

    // ──────────────────────────────────────────────
    // ERC-1155 minimal storage
    // ──────────────────────────────────────────────

    /// @notice token ID → owner → balance
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // ──────────────────────────────────────────────
    // Events
    // ──────────────────────────────────────────────

    event InvoiceSubmitted(uint256 indexed tokenId, address indexed submitter);
    event GovernmentInvoiceSubmitted(uint256 indexed tokenId, address indexed submitter);
    event FreelancerInvoiceSubmitted(uint256 indexed tokenId, address indexed submitter);
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );
    event CreditOracleUpdated(address indexed oracle);
    event FinancingPoolUpdated(address indexed pool);

    // ──────────────────────────────────────────────
    // Modifiers
    // ──────────────────────────────────────────────

    modifier onlyVerified() {
        require(
            credentialRegistry.isVerified(msg.sender),
            "InvoiceVault: caller not verified"
        );
        _;
    }

    modifier onlyVerifiedKYB() {
        require(
            credentialRegistry.isVerifiedKYB(msg.sender),
            "InvoiceVault: KYB credential required"
        );
        _;
    }

    modifier onlyVerifiedKYC() {
        require(
            credentialRegistry.isVerifiedKYC(msg.sender),
            "InvoiceVault: KYC_INDIVIDUAL credential required"
        );
        _;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "InvoiceVault: caller is not the owner");
        _;
    }

    // ──────────────────────────────────────────────
    // Constructor
    // ──────────────────────────────────────────────

    constructor(address _credentialRegistry) {
        require(_credentialRegistry != address(0), "InvoiceVault: zero address");
        credentialRegistry = ICredentialRegistry(_credentialRegistry);
        owner = msg.sender;
    }

    // ──────────────────────────────────────────────
    // Admin
    // ──────────────────────────────────────────────

    /// @notice Set the CreditOracle address (called after CreditOracle is deployed)
    function setCreditOracle(address _creditOracle) external onlyOwner {
        require(_creditOracle != address(0), "InvoiceVault: zero address");
        creditOracle = _creditOracle;
        emit CreditOracleUpdated(_creditOracle);
    }

    /// @notice Set the FinancingPool address (called after FinancingPool is deployed)
    function setFinancingPool(address _financingPool) external onlyOwner {
        require(_financingPool != address(0), "InvoiceVault: zero address");
        financingPool = _financingPool;
        emit FinancingPoolUpdated(_financingPool);
    }

    // ──────────────────────────────────────────────
    // Invoice submission
    // ──────────────────────────────────────────────

    /// @notice Submit a corporate encrypted invoice (Wave 1). Mints an ERC-1155 token.
    /// @param encryptedAmount  Encrypted invoice amount (from cofhe/sdk)
    /// @param encryptedDueDate Encrypted due date as unix timestamp (from cofhe/sdk)
    /// @param encryptedBuyer   Encrypted buyer name as bytes
    function submitInvoice(
        InEuint128 calldata encryptedAmount,
        InEuint128 calldata encryptedDueDate,
        bytes calldata encryptedBuyer
    ) external onlyVerified {
        euint128 amount = FHE.asEuint128(encryptedAmount);
        euint128 dueDate = FHE.asEuint128(encryptedDueDate);

        uint256 tokenId = nextTokenId++;

        // Store encrypted invoice data
        invoices[tokenId] = Invoice({
            submitter: msg.sender,
            encryptedAmount: amount,
            encryptedDueDate: dueDate,
            encryptedBuyer: encryptedBuyer,
            encryptedGovRef: euint128.wrap(0),
            tier: PoolTier.INSTITUTIONAL,
            submittedAt: block.timestamp,
            active: true
        });

        userInvoices[msg.sender].push(tokenId);

        _grantFheAccess(tokenId, amount, dueDate);

        // Mint ERC-1155 token (1 unit per invoice)
        _balances[tokenId][msg.sender] = 1;
        emit TransferSingle(msg.sender, address(0), msg.sender, tokenId, 1);
        emit InvoiceSubmitted(tokenId, msg.sender);
    }

    /// @notice Wave 2: Submit a government contract receivable. KYB required.
    /// @param encryptedAmount  Encrypted invoice amount
    /// @param encryptedDueDate Encrypted due date as unix timestamp
    /// @param encryptedBuyer   Encrypted buyer name as bytes
    /// @param encryptedGovRef  Encrypted government contract reference number
    function submitGovernmentInvoice(
        InEuint128 calldata encryptedAmount,
        InEuint128 calldata encryptedDueDate,
        bytes calldata encryptedBuyer,
        InEuint128 calldata encryptedGovRef
    ) external onlyVerifiedKYB {
        euint128 amount = FHE.asEuint128(encryptedAmount);
        euint128 dueDate = FHE.asEuint128(encryptedDueDate);
        euint128 govRef = FHE.asEuint128(encryptedGovRef);

        uint256 tokenId = nextTokenId++;

        invoices[tokenId] = Invoice({
            submitter: msg.sender,
            encryptedAmount: amount,
            encryptedDueDate: dueDate,
            encryptedBuyer: encryptedBuyer,
            encryptedGovRef: govRef,
            tier: PoolTier.GOVERNMENT,
            submittedAt: block.timestamp,
            active: true
        });

        userInvoices[msg.sender].push(tokenId);

        _grantFheAccess(tokenId, amount, dueDate);

        // Grant CreditOracle access to the gov reference for scoring
        FHE.allowThis(govRef);
        FHE.allowSender(govRef);
        if (creditOracle != address(0)) {
            FHE.allow(govRef, creditOracle);
        }

        _balances[tokenId][msg.sender] = 1;
        emit TransferSingle(msg.sender, address(0), msg.sender, tokenId, 1);
        emit GovernmentInvoiceSubmitted(tokenId, msg.sender);
    }

    /// @notice Wave 2: Submit a freelancer invoice. KYC_INDIVIDUAL required. Routed to retail pool.
    /// @param encryptedAmount  Encrypted invoice amount
    /// @param encryptedDueDate Encrypted due date as unix timestamp
    /// @param encryptedBuyer   Encrypted buyer name as bytes
    function submitFreelancerInvoice(
        InEuint128 calldata encryptedAmount,
        InEuint128 calldata encryptedDueDate,
        bytes calldata encryptedBuyer
    ) external onlyVerifiedKYC {
        euint128 amount = FHE.asEuint128(encryptedAmount);
        euint128 dueDate = FHE.asEuint128(encryptedDueDate);

        uint256 tokenId = nextTokenId++;

        invoices[tokenId] = Invoice({
            submitter: msg.sender,
            encryptedAmount: amount,
            encryptedDueDate: dueDate,
            encryptedBuyer: encryptedBuyer,
            encryptedGovRef: euint128.wrap(0),
            tier: PoolTier.RETAIL,
            submittedAt: block.timestamp,
            active: true
        });

        userInvoices[msg.sender].push(tokenId);

        _grantFheAccess(tokenId, amount, dueDate);

        _balances[tokenId][msg.sender] = 1;
        emit TransferSingle(msg.sender, address(0), msg.sender, tokenId, 1);
        emit FreelancerInvoiceSubmitted(tokenId, msg.sender);
    }

    /// @dev Internal: grant FHE access to contract, sender, oracle, and pool
    function _grantFheAccess(uint256 tokenId, euint128 amount, euint128 dueDate) internal {
        tokenId; // suppress unused warning — used by caller for context
        FHE.allowThis(amount);
        FHE.allowThis(dueDate);
        FHE.allowSender(amount);
        FHE.allowSender(dueDate);
        if (creditOracle != address(0)) {
            FHE.allow(amount, creditOracle);
            FHE.allow(dueDate, creditOracle);
        }
        if (financingPool != address(0)) {
            FHE.allow(amount, financingPool);
            FHE.allow(dueDate, financingPool);
        }
    }

    // ──────────────────────────────────────────────
    // Read functions
    // ──────────────────────────────────────────────

    /// @notice Get invoice metadata (non-encrypted fields)
    function getInvoiceMeta(uint256 tokenId)
        external
        view
        returns (address submitter, uint256 submittedAt, bool active)
    {
        Invoice storage inv = invoices[tokenId];
        return (inv.submitter, inv.submittedAt, inv.active);
    }

    /// @notice Get encrypted amount handle (caller must have FHE access)
    function getEncryptedAmount(uint256 tokenId) external view returns (euint128) {
        return invoices[tokenId].encryptedAmount;
    }

    /// @notice Get encrypted due date handle (caller must have FHE access)
    function getEncryptedDueDate(uint256 tokenId) external view returns (euint128) {
        return invoices[tokenId].encryptedDueDate;
    }

    /// @notice Wave 2: Get encrypted government reference handle (caller must have FHE access)
    function getEncryptedGovRef(uint256 tokenId) external view returns (euint128) {
        return invoices[tokenId].encryptedGovRef;
    }

    /// @notice Wave 2: Get the pool tier for a token
    function getPoolTier(uint256 tokenId) external view returns (PoolTier) {
        return invoices[tokenId].tier;
    }

    /// @notice Get all token IDs for a user
    function getUserInvoices(address user) external view returns (uint256[] memory) {
        return userInvoices[user];
    }

    /// @notice Get total number of invoices submitted
    function totalInvoices() external view returns (uint256) {
        return nextTokenId - 1;
    }

    /// @notice ERC-1155 balanceOf
    function balanceOf(address account, uint256 id) external view returns (uint256) {
        return _balances[id][account];
    }

    // ──────────────────────────────────────────────
    // Token management (used by FinancingPool)
    // ──────────────────────────────────────────────

    /// @notice Transfer token to escrow (called by FinancingPool on funding)
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata
    ) external {
        require(
            msg.sender == from || msg.sender == owner || msg.sender == financingPool,
            "InvoiceVault: not authorized"
        );
        require(_balances[id][from] >= amount, "InvoiceVault: insufficient balance");

        _balances[id][from] -= amount;
        _balances[id][to] += amount;

        emit TransferSingle(msg.sender, from, to, id, amount);
    }

    /// @notice Burn token (called on settlement)
    function burn(address account, uint256 id, uint256 amount) external {
        require(
            msg.sender == account || msg.sender == owner || msg.sender == financingPool,
            "InvoiceVault: not authorized"
        );
        require(_balances[id][account] >= amount, "InvoiceVault: insufficient balance");

        _balances[id][account] -= amount;
        invoices[id].active = false;

        emit TransferSingle(msg.sender, account, address(0), id, amount);
    }

    /// @notice Grant FHE access to a new address for a token's encrypted data
    function grantAccess(uint256 tokenId, address grantee) external onlyOwner {
        Invoice storage inv = invoices[tokenId];
        FHE.allow(inv.encryptedAmount, grantee);
        FHE.allow(inv.encryptedDueDate, grantee);
    }
}
