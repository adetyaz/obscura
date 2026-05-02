export const BuyerOracleABI = [
	{
		anonymous: false,
		inputs: [
			{ indexed: true, internalType: 'bytes32', name: 'requestId', type: 'bytes32' },
			{ indexed: true, internalType: 'bytes32', name: 'buyerKey', type: 'bytes32' },
			{ indexed: false, internalType: 'string', name: 'jurisdiction', type: 'string' }
		],
		name: 'BuyerScoreRequested',
		type: 'event'
	},
	{
		anonymous: false,
		inputs: [
			{ indexed: true, internalType: 'bytes32', name: 'buyerKey', type: 'bytes32' },
			{ indexed: false, internalType: 'uint256', name: 'timestamp', type: 'uint256' }
		],
		name: 'BuyerScoreUpdated',
		type: 'event'
	},
	{
		inputs: [
			{ internalType: 'bytes32', name: 'buyerKey', type: 'bytes32' },
			{ internalType: 'string', name: 'jurisdiction', type: 'string' }
		],
		name: 'requestBuyerScore',
		outputs: [{ internalType: 'bytes32', name: 'requestId', type: 'bytes32' }],
		stateMutability: 'nonpayable',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'bytes32', name: 'buyerKey', type: 'bytes32' }],
		name: 'lastUpdated',
		outputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
		stateMutability: 'view',
		type: 'function'
	}
] as const;
