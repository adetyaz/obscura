// SPDX-License-Identifier: MIT
pragma solidity ^0.8.25;

import "@fhenixprotocol/cofhe-contracts/FHE.sol";

/// @title CredentialRegistry
/// @notice Stores encrypted KYB credentials and exposes plaintext verification status.
///         Wave 1: owner manually sets verified status via setVerified().
contract CredentialRegistry {
    address public owner;

    /// @notice Encrypted credential data per wallet (for future Privara integration)
    mapping(address => euint128) private credentials;

    /// @notice Plaintext verification status — gates access to InvoiceVault
    mapping(address => bool) public verified;

    event VerificationUpdated(address indexed wallet, bool status);
    event CredentialStored(address indexed wallet);

    modifier onlyOwner() {
        require(msg.sender == owner, "CredentialRegistry: caller is not the owner");
        _;
    }

    constructor() {
        owner = msg.sender;
    }

    /// @notice Wave 1 mock KYB — owner sets verification status directly
    /// @param wallet The address to verify or unverify
    /// @param status True if verified, false to revoke
    function setVerified(address wallet, bool status) external onlyOwner {
        verified[wallet] = status;
        emit VerificationUpdated(wallet, status);
    }

    /// @notice Store an encrypted credential (for future use with Privara)
    /// @param encryptedCredential The encrypted credential data from cofhejs
    function storeCredential(InEuint128 calldata encryptedCredential) external {
        euint128 credential = FHE.asEuint128(encryptedCredential);

        credentials[msg.sender] = credential;
        FHE.allowThis(credential);
        FHE.allowSender(credential);

        emit CredentialStored(msg.sender);
    }

    /// @notice Check if a wallet is KYB-verified
    /// @param wallet The address to check
    /// @return True if the wallet has been verified
    function isVerified(address wallet) external view returns (bool) {
        return verified[wallet];
    }

    /// @notice Transfer ownership
    /// @param newOwner The new owner address
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "CredentialRegistry: zero address");
        owner = newOwner;
    }
}
