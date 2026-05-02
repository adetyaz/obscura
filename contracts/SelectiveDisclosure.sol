// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@fhenixprotocol/cofhe-contracts/FHE.sol";

contract SelectiveDisclosure {
    enum ProofType {
        TOTAL_RECEIVABLES_EXCEED,
        ALL_COUNTERPARTIES_CLEAR
    }

    struct ProofRequest {
        address requester;
        ProofType proofType;
        uint256 threshold;
        uint256 requestedAt;
        bool fulfilled;
        bool result;
    }

    mapping(bytes32 => ProofRequest) public proofRequests;

    event ProofRequested(
        bytes32 indexed requestId,
        address requester,
        ProofType proofType,
        uint256 threshold
    );

    event ProofFulfilled(bytes32 indexed requestId, bool result);

    function requestProof(ProofType proofType, uint256 threshold) external returns (bytes32 requestId) {
        requestId = keccak256(
            abi.encodePacked(msg.sender, proofType, threshold, block.timestamp)
        );

        proofRequests[requestId] = ProofRequest({
            requester: msg.sender,
            proofType: proofType,
            threshold: threshold,
            requestedAt: block.timestamp,
            fulfilled: false,
            result: false
        });

        emit ProofRequested(requestId, msg.sender, proofType, threshold);
    }

    // Called after async FHE decryption flow (decryptForTx) by the requester
    function fulfillProof(bytes32 requestId, bool result) external {
        ProofRequest storage req = proofRequests[requestId];
        require(!req.fulfilled, "Already fulfilled");
        require(msg.sender == req.requester, "Not requester");

        req.result = result;
        req.fulfilled = true;

        emit ProofFulfilled(requestId, result);
    }
}
