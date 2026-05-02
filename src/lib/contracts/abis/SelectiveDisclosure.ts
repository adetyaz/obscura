export const SelectiveDisclosureABI = [
	{
		anonymous: false,
		inputs: [
			{ indexed: true, internalType: 'bytes32', name: 'requestId', type: 'bytes32' },
			{ indexed: false, internalType: 'address', name: 'requester', type: 'address' },
			{ indexed: false, internalType: 'uint8', name: 'proofType', type: 'uint8' },
			{ indexed: false, internalType: 'uint256', name: 'threshold', type: 'uint256' }
		],
		name: 'ProofRequested',
		type: 'event'
	},
	{
		anonymous: false,
		inputs: [
			{ indexed: true, internalType: 'bytes32', name: 'requestId', type: 'bytes32' },
			{ indexed: false, internalType: 'bool', name: 'result', type: 'bool' }
		],
		name: 'ProofFulfilled',
		type: 'event'
	},
	{
		inputs: [
			{ internalType: 'uint8', name: 'proofType', type: 'uint8' },
			{ internalType: 'uint256', name: 'threshold', type: 'uint256' }
		],
		name: 'requestProof',
		outputs: [{ internalType: 'bytes32', name: 'requestId', type: 'bytes32' }],
		stateMutability: 'nonpayable',
		type: 'function'
	},
	{
		inputs: [
			{ internalType: 'bytes32', name: 'requestId', type: 'bytes32' },
			{ internalType: 'bool', name: 'result', type: 'bool' }
		],
		name: 'fulfillProof',
		outputs: [],
		stateMutability: 'nonpayable',
		type: 'function'
	}
] as const;
