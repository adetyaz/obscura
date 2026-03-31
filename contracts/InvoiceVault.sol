// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@fhenixprotocol/cofhe-contracts/FHE.sol";

interface ICredentialRegistry {
    function isVerified(address wallet) external view returns (bool);
}

/// @title InvoiceVault
/// @notice Accepts encrypted invoice data, stores it, and mints ERC-1155 tokens.
///         Only KYB-verified addresses can submit invoices.
contract InvoiceVault {
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

    /// @notice Submit an encrypted invoice. Mints an ERC-1155 token.
    /// @param encryptedAmount  Encrypted invoice amount (from cofhejs)
    /// @param encryptedDueDate Encrypted due date as unix timestamp (from cofhejs)
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
            submittedAt: block.timestamp,
            active: true
        });

        userInvoices[msg.sender].push(tokenId);

        // FHE access control — contract needs access to stored values
        FHE.allowThis(amount);
        FHE.allowThis(dueDate);

        // Submitter can view their own encrypted data
        FHE.allowSender(amount);
        FHE.allowSender(dueDate);

        // Grant CreditOracle access to run scoring
        if (creditOracle != address(0)) {
            FHE.allow(amount, creditOracle);
            FHE.allow(dueDate, creditOracle);
        }

        // Grant FinancingPool access to compute advance/fee amounts
        if (financingPool != address(0)) {
            FHE.allow(amount, financingPool);
            FHE.allow(dueDate, financingPool);
        }

        // Mint ERC-1155 token (1 unit per invoice)
        _balances[tokenId][msg.sender] = 1;
        emit TransferSingle(msg.sender, address(0), msg.sender, tokenId, 1);
        emit InvoiceSubmitted(tokenId, msg.sender);
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
