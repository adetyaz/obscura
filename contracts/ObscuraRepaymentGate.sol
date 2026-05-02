// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import { IConditionResolver } from "@reineira-os/shared/contracts/interfaces/extensions/IConditionResolver.sol";

contract ObscuraRepaymentGate is IConditionResolver, ERC165 {
    // tokenId on Base Sepolia => escrowId on Arbitrum Sepolia
    mapping(uint256 => uint256) public tokenToEscrow;

    // escrowId => whether repayment has been confirmed
    mapping(uint256 => bool) public repaymentConfirmed;

    // Trusted relayer that submits repayment confirmations
    address public relayer;

    event RepaymentConfirmed(uint256 indexed escrowId, uint256 indexed tokenId, address indexed relayer);

    error NotRelayer();

    constructor(address _relayer) {
        relayer = _relayer;
    }

    function onConditionSet(uint256 escrowId, bytes calldata data) external override {
        uint256 tokenId = abi.decode(data, (uint256));
        tokenToEscrow[tokenId] = escrowId;
    }

    function isConditionMet(uint256 escrowId) external view override returns (bool) {
        return repaymentConfirmed[escrowId];
    }

    // Called by the trusted relayer when RepaymentReceived fires on Base Sepolia
    function confirmRepayment(uint256 tokenId) external {
        if (msg.sender != relayer) revert NotRelayer();

        uint256 escrowId = tokenToEscrow[tokenId];
        repaymentConfirmed[escrowId] = true;
        emit RepaymentConfirmed(escrowId, tokenId, msg.sender);
    }

    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(IConditionResolver).interfaceId || super.supportsInterface(interfaceId);
    }
}
