// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import { FunctionsClient } from "@chainlink/contracts/src/v0.8/functions/v1_0_0/FunctionsClient.sol";
import { FunctionsRequest } from "@chainlink/contracts/src/v0.8/functions/v1_0_0/libraries/FunctionsRequest.sol";
import "@fhenixprotocol/cofhe-contracts/FHE.sol";

contract BuyerOracle is FunctionsClient {
    using FunctionsRequest for FunctionsRequest.Request;

    // Base Sepolia Chainlink Functions router
    address public constant FUNCTIONS_ROUTER = 0xf9B8fc078197181C841c296C876945aaa425B278;
    bytes32 public constant DON_ID = 0x66756e2d626173652d7365706f6c69612d310000000000000000000000000000;
    uint32 public constant GAS_LIMIT = 300_000;

    uint64 public subscriptionId;
    address public owner;

    // buyerKey => encrypted score
    mapping(bytes32 => euint8) private encryptedBuyerScores;
    mapping(bytes32 => uint256) public lastUpdated;
    mapping(bytes32 => bytes32) private requestToBuyerKey;

    event BuyerScoreRequested(bytes32 indexed requestId, bytes32 indexed buyerKey, string jurisdiction);
    event BuyerScoreUpdated(bytes32 indexed buyerKey, uint256 timestamp);

    error NotOwner();

    // JavaScript source executed by Chainlink Functions DON
    string public constant SOURCE =
        "const buyerRef = args[0];"
        "const jurisdiction = args[1];"
        "let score = 0;"
        "if (jurisdiction === 'NG') {"
        "  const r = await Functions.makeHttpRequest({"
        "    url: `https://api.cac.gov.ng/company/${buyerRef}`"
        "  });"
        "  score = r.data?.status === 'active' ? 75 : 0;"
        "} else if (jurisdiction === 'UK') {"
        "  const r = await Functions.makeHttpRequest({"
        "    url: `https://api.company-information.service.gov.uk/company/${buyerRef}`,"
        "    headers: { 'Authorization': secrets.COMPANIES_HOUSE_KEY }"
        "  });"
        "  score = r.data?.company_status === 'active' ? 80 : 0;"
        "}"
        "return Functions.encodeUint256(score);";

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(uint64 _subscriptionId) FunctionsClient(FUNCTIONS_ROUTER) {
        owner = msg.sender;
        subscriptionId = _subscriptionId;
    }

    function setSubscriptionId(uint64 _subscriptionId) external onlyOwner {
        subscriptionId = _subscriptionId;
    }

    function requestBuyerScore(
        bytes32 buyerKey,
        string calldata jurisdiction
    ) external returns (bytes32 requestId) {
        FunctionsRequest.Request memory req;
        req.initializeRequestForInlineJavaScript(SOURCE);

        string[] memory args = new string[](2);
        args[0] = bytes32ToString(buyerKey);
        args[1] = jurisdiction;
        req.setArgs(args);

        requestId = _sendRequest(req.encodeCBOR(), subscriptionId, GAS_LIMIT, DON_ID);
        requestToBuyerKey[requestId] = buyerKey;

        emit BuyerScoreRequested(requestId, buyerKey, jurisdiction);
    }

    function fulfillRequest(
        bytes32 requestId,
        bytes memory response,
        bytes memory /* err */
    ) internal override {
        bytes32 buyerKey = requestToBuyerKey[requestId];
        uint256 rawScore = abi.decode(response, (uint256));

        euint8 encrypted = FHE.asEuint8(uint8(rawScore));
        FHE.allowThis(encrypted);
        encryptedBuyerScores[buyerKey] = encrypted;
        lastUpdated[buyerKey] = block.timestamp;

        emit BuyerScoreUpdated(buyerKey, block.timestamp);
    }

    function getEncryptedScore(bytes32 buyerKey) external view returns (euint8) {
        return encryptedBuyerScores[buyerKey];
    }

    function bytes32ToString(bytes32 b) internal pure returns (string memory) {
        return string(abi.encodePacked(b));
    }
}
