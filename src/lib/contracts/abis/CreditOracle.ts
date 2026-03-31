export const CreditOracleABI = [
	{
		inputs: [{ internalType: 'address', name: '_invoiceVault', type: 'address' }],
		stateMutability: 'nonpayable',
		type: 'constructor'
	},
	{
		inputs: [{ internalType: 'int32', name: 'value', type: 'int32' }],
		name: 'SecurityZoneOutOfBounds',
		type: 'error'
	},
	{
		anonymous: false,
		inputs: [
			{ indexed: true, internalType: 'uint256', name: 'tokenId', type: 'uint256' },
			{ indexed: false, internalType: 'uint8', name: 'score', type: 'uint8' }
		],
		name: 'ScoreFinalized',
		type: 'event'
	},
	{
		anonymous: false,
		inputs: [{ indexed: true, internalType: 'uint256', name: 'tokenId', type: 'uint256' }],
		name: 'ScoreRequested',
		type: 'event'
	},
	{
		inputs: [],
		name: 'MAX_AMOUNT',
		outputs: [{ internalType: 'uint128', name: '', type: 'uint128' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [],
		name: 'MIN_TENOR_SECONDS',
		outputs: [{ internalType: 'uint128', name: '', type: 'uint128' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [],
		name: 'SCORE_AMOUNT_OK',
		outputs: [{ internalType: 'uint8', name: '', type: 'uint8' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [],
		name: 'SCORE_BUYER_OK',
		outputs: [{ internalType: 'uint8', name: '', type: 'uint8' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [],
		name: 'SCORE_DUEDATE_OK',
		outputs: [{ internalType: 'uint8', name: '', type: 'uint8' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [
			{ internalType: 'uint256', name: 'tokenId', type: 'uint256' },
			{ internalType: 'uint8', name: '_decryptedScore', type: 'uint8' },
			{ internalType: 'bytes', name: '_signature', type: 'bytes' }
		],
		name: 'finalizeScore',
		outputs: [],
		stateMutability: 'nonpayable',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'uint256', name: 'tokenId', type: 'uint256' }],
		name: 'getEncryptedScoreHandle',
		outputs: [{ internalType: 'bytes32', name: '', type: 'bytes32' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'uint256', name: 'tokenId', type: 'uint256' }],
		name: 'getScore',
		outputs: [{ internalType: 'uint8', name: '', type: 'uint8' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [],
		name: 'invoiceVault',
		outputs: [{ internalType: 'contract IInvoiceVault', name: '', type: 'address' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'uint256', name: 'tokenId', type: 'uint256' }],
		name: 'isScoreReady',
		outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [],
		name: 'owner',
		outputs: [{ internalType: 'address', name: '', type: 'address' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'uint256', name: 'tokenId', type: 'uint256' }],
		name: 'requestScore',
		outputs: [],
		stateMutability: 'nonpayable',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
		name: 'scoreReady',
		outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
		name: 'scoreRequested',
		outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
		name: 'scores',
		outputs: [{ internalType: 'uint8', name: '', type: 'uint8' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'address', name: 'newOwner', type: 'address' }],
		name: 'transferOwnership',
		outputs: [],
		stateMutability: 'nonpayable',
		type: 'function'
	}
] as const;
