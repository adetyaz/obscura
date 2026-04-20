// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@fhenixprotocol/cofhe-contracts/FHE.sol";

/// @title CredentialRegistry
/// @notice Stores encrypted KYB/KYC credentials and exposes plaintext verification status.
///         Wave 1: owner manually sets verified status via setVerified().
///         Wave 2: adds individual KYC tier for freelancers via setVerifiedKYC().
contract CredentialRegistry {
    // ──────────────────────────────────────────────
    // Wave 2: Credential type enum
    // ──────────────────────────────────────────────

    enum CredentialType { NONE, KYB, KYC_INDIVIDUAL }

    address public owner;

    /// @notice Encrypted credential data per wallet (for future Privara integration)
    mapping(address => euint128) private credentials;

    /// @notice Plaintext verification status — gates access to InvoiceVault (Wave 1 compat)
    mapping(address => bool) public verified;

    /// @notice Wave 2: credential type per wallet
    mapping(address => CredentialType) private credentialTypes;

    event VerificationUpdated(address indexed wallet, bool status);
    event CredentialStored(address indexed wallet);
    event KYBVerified(address indexed wallet);
    event KYCVerified(address indexed wallet);

    modifier onlyOwner() {
        require(msg.sender == owner, "CredentialRegistry: caller is not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    // ──────────────────────────────────────────────
    // Wave 1: KYB (backward compatible)
    // ──────────────────────────────────────────────

    /// @notice Wave 1 mock KYB — owner sets verification status directly
    /// @param wallet The address to verify or unverify
    /// @param status True if verified, false to revoke
    function setVerified(address wallet, bool status) external onlyOwner {
        verified[wallet] = status;
        if (status) {
            credentialTypes[wallet] = CredentialType.KYB;
        } else if (credentialTypes[wallet] == CredentialType.KYB) {
            credentialTypes[wallet] = CredentialType.NONE;
        }
        emit VerificationUpdated(wallet, status);
    }

    /// @notice Wave 1 mock KYB — any wallet can self-verify for testing / preseed
    function selfVerify() external {
        verified[msg.sender] = true;
        credentialTypes[msg.sender] = CredentialType.KYB;
        emit VerificationUpdated(msg.sender, true);
        emit KYBVerified(msg.sender);
    }

    // ──────────────────────────────────────────────
    // Wave 2: KYB via Privara
    // ──────────────────────────────────────────────

    /// @notice Set KYB credential — called by owner/Privara after KYB verification
    /// @param wallet The address to mark as KYB-verified
    function setVerifiedKYB(address wallet) external onlyOwner {
        require(wallet != address(0), "CredentialRegistry: zero address");
        verified[wallet] = true;
        credentialTypes[wallet] = CredentialType.KYB;
        emit VerificationUpdated(wallet, true);
        emit KYBVerified(wallet);
    }

    // ──────────────────────────────────────────────
    // Wave 2: Individual KYC for freelancers
    // ──────────────────────────────────────────────

    /// @notice Set individual KYC credential — called by owner/Privara after KYC verification
    /// @param wallet The address to mark as KYC_INDIVIDUAL-verified
    function setVerifiedKYC(address wallet) external onlyOwner {
        require(wallet != address(0), "CredentialRegistry: zero address");
        credentialTypes[wallet] = CredentialType.KYC_INDIVIDUAL;
        // isVerified() returns true for both KYB and KYC_INDIVIDUAL
        verified[wallet] = true;
        emit VerificationUpdated(wallet, true);
        emit KYCVerified(wallet);
    }

    /// @notice Wave 2 mock KYC — any wallet can self-register KYC_INDIVIDUAL for testing
    function selfVerifyKYC() external {
        credentialTypes[msg.sender] = CredentialType.KYC_INDIVIDUAL;
        verified[msg.sender] = true;
        emit VerificationUpdated(msg.sender, true);
        emit KYCVerified(msg.sender);
    }

    // ──────────────────────────────────────────────
    // Read functions
    // ──────────────────────────────────────────────

    /// @notice Check if a wallet is verified (KYB or KYC_INDIVIDUAL)
    /// @param wallet The address to check
    /// @return True if the wallet has been verified by any credential type
    function isVerified(address wallet) external view returns (bool) {
        return verified[wallet];
    }

    /// @notice Get the credential type for a wallet
    /// @param wallet The address to check
    function getCredentialType(address wallet) external view returns (CredentialType) {
        return credentialTypes[wallet];
    }

    /// @notice Check if a wallet holds a KYB credential specifically
    /// @param wallet The address to check
    function isVerifiedKYB(address wallet) external view returns (bool) {
        return credentialTypes[wallet] == CredentialType.KYB;
    }

    /// @notice Check if a wallet holds a KYC_INDIVIDUAL credential specifically
    /// @param wallet The address to check
    function isVerifiedKYC(address wallet) external view returns (bool) {
        return credentialTypes[wallet] == CredentialType.KYC_INDIVIDUAL;
    }

    // ──────────────────────────────────────────────
    // Credential storage
    // ──────────────────────────────────────────────

    /// @notice Store an encrypted credential (for future use with Privara)
    /// @param encryptedCredential The encrypted credential data from cofhe/sdk
    function storeCredential(InEuint128 calldata encryptedCredential) external {
        euint128 credential = FHE.asEuint128(encryptedCredential);

        credentials[msg.sender] = credential;
        FHE.allowThis(credential);
        FHE.allowSender(credential);

        emit CredentialStored(msg.sender);
    }

    // ──────────────────────────────────────────────
    // Admin
    // ──────────────────────────────────────────────

    /// @notice Transfer ownership
    /// @param newOwner The new owner address
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "CredentialRegistry: zero address");
        owner = newOwner;
    }
}
