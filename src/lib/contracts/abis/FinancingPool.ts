export const financingPoolAbi = [
	{
		inputs: [
			{ internalType: 'address', name: '_invoiceVault', type: 'address' },
			{ internalType: 'address', name: '_creditOracle', type: 'address' }
		],
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
			{ indexed: true, internalType: 'address', name: 'lender', type: 'address' },
			{ indexed: true, internalType: 'address', name: 'smeAddress', type: 'address' },
			{ indexed: false, internalType: 'uint16', name: 'advanceRateBps', type: 'uint16' },
			{ indexed: false, internalType: 'uint16', name: 'discountRateBps', type: 'uint16' }
		],
		name: 'InvoiceFunded',
		type: 'event'
	},
	{
		anonymous: false,
		inputs: [
			{ indexed: true, internalType: 'uint256', name: 'tokenId', type: 'uint256' },
			{ indexed: true, internalType: 'address', name: 'lender', type: 'address' },
			{ indexed: true, internalType: 'address', name: 'sme', type: 'address' }
		],
		name: 'PositionSettled',
		type: 'event'
	},
	{
		anonymous: false,
		inputs: [
			{ indexed: true, internalType: 'uint256', name: 'tokenId', type: 'uint256' },
			{ indexed: true, internalType: 'address', name: 'sme', type: 'address' },
			{ indexed: false, internalType: 'uint256', name: 'amount', type: 'uint256' }
		],
		name: 'RepaymentReceived',
		type: 'event'
	},
	{
		inputs: [],
		name: 'BPS',
		outputs: [{ internalType: 'uint128', name: '', type: 'uint128' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [],
		name: 'creditOracle',
		outputs: [{ internalType: 'contract ICreditOracle', name: '', type: 'address' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [
			{ internalType: 'uint256', name: 'tokenId', type: 'uint256' },
			{ internalType: 'uint128', name: '_decryptedRepay', type: 'uint128' },
			{ internalType: 'bytes', name: '_signature', type: 'bytes' }
		],
		name: 'finalizeSettlement',
		outputs: [],
		stateMutability: 'nonpayable',
		type: 'function'
	},
	{
		inputs: [
			{ internalType: 'uint256', name: 'tokenId', type: 'uint256' },
			{ internalType: 'uint16', name: 'advanceRateBps', type: 'uint16' },
			{ internalType: 'uint16', name: 'discountRateBps', type: 'uint16' }
		],
		name: 'fundInvoice',
		outputs: [],
		stateMutability: 'nonpayable',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'uint256', name: 'tokenId', type: 'uint256' }],
		name: 'getEncryptedAdvance',
		outputs: [{ internalType: 'euint128', name: '', type: 'bytes32' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'uint256', name: 'tokenId', type: 'uint256' }],
		name: 'getEncryptedFee',
		outputs: [{ internalType: 'euint128', name: '', type: 'bytes32' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'uint256', name: 'tokenId', type: 'uint256' }],
		name: 'getEncryptedRepay',
		outputs: [{ internalType: 'euint128', name: '', type: 'bytes32' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'address', name: 'lender', type: 'address' }],
		name: 'getLenderPositions',
		outputs: [{ internalType: 'uint256[]', name: '', type: 'uint256[]' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'uint256', name: 'tokenId', type: 'uint256' }],
		name: 'getPositionMeta',
		outputs: [
			{ internalType: 'address', name: 'lender', type: 'address' },
			{ internalType: 'address', name: 'sme', type: 'address' },
			{ internalType: 'uint16', name: 'advanceRateBps', type: 'uint16' },
			{ internalType: 'uint16', name: 'discountRateBps', type: 'uint16' },
			{ internalType: 'uint256', name: 'fundedAt', type: 'uint256' },
			{ internalType: 'bool', name: 'settled', type: 'bool' }
		],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'uint256', name: 'tokenId', type: 'uint256' }],
		name: 'getRepayAmount',
		outputs: [{ internalType: 'uint128', name: '', type: 'uint128' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [],
		name: 'invoiceVault',
		outputs: [{ internalType: 'contract IInvoiceVaultFP', name: '', type: 'address' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
		name: 'isFunded',
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
		inputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
		name: 'positions',
		outputs: [
			{ internalType: 'uint256', name: 'tokenId', type: 'uint256' },
			{ internalType: 'address', name: 'lender', type: 'address' },
			{ internalType: 'address', name: 'sme', type: 'address' },
			{ internalType: 'uint16', name: 'advanceRateBps', type: 'uint16' },
			{ internalType: 'uint16', name: 'discountRateBps', type: 'uint16' },
			{ internalType: 'uint256', name: 'fundedAt', type: 'uint256' },
			{ internalType: 'bool', name: 'settled', type: 'bool' },
			{ internalType: 'euint128', name: 'encAdvanceAmount', type: 'bytes32' },
			{ internalType: 'euint128', name: 'encFeeAmount', type: 'bytes32' },
			{ internalType: 'euint128', name: 'encRepayAmount', type: 'bytes32' }
		],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'uint256', name: 'tokenId', type: 'uint256' }],
		name: 'repay',
		outputs: [],
		stateMutability: 'payable',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
		name: 'repayAmountPlain',
		outputs: [{ internalType: 'uint128', name: '', type: 'uint128' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'uint256', name: 'tokenId', type: 'uint256' }],
		name: 'requestSettlement',
		outputs: [],
		stateMutability: 'nonpayable',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
		name: 'settlementReady',
		outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'uint256', name: '', type: 'uint256' }],
		name: 'settlementRequested',
		outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'address', name: 'newOwner', type: 'address' }],
		name: 'transferOwnership',
		outputs: [],
		stateMutability: 'nonpayable',
		type: 'function'
	},
	{ stateMutability: 'payable', type: 'receive' }
] as const;
