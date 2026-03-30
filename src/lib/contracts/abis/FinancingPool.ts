export const financingPoolAbi = [
	// ── Constructor ──
	{
		type: 'constructor',
		inputs: [
			{ name: '_invoiceVault', type: 'address', internalType: 'address' },
			{ name: '_creditOracle', type: 'address', internalType: 'address' }
		],
		stateMutability: 'nonpayable'
	},

	// ── Events ──
	{
		type: 'event',
		name: 'InvoiceFunded',
		inputs: [
			{ name: 'tokenId', type: 'uint256', indexed: true, internalType: 'uint256' },
			{ name: 'lender', type: 'address', indexed: true, internalType: 'address' },
			{ name: 'smeAddress', type: 'address', indexed: true, internalType: 'address' },
			{ name: 'advanceRateBps', type: 'uint16', indexed: false, internalType: 'uint16' },
			{ name: 'discountRateBps', type: 'uint16', indexed: false, internalType: 'uint16' }
		],
		anonymous: false
	},
	{
		type: 'event',
		name: 'RepaymentReceived',
		inputs: [
			{ name: 'tokenId', type: 'uint256', indexed: true, internalType: 'uint256' },
			{ name: 'sme', type: 'address', indexed: true, internalType: 'address' },
			{ name: 'amount', type: 'uint256', indexed: false, internalType: 'uint256' }
		],
		anonymous: false
	},
	{
		type: 'event',
		name: 'PositionSettled',
		inputs: [
			{ name: 'tokenId', type: 'uint256', indexed: true, internalType: 'uint256' },
			{ name: 'lender', type: 'address', indexed: true, internalType: 'address' },
			{ name: 'sme', type: 'address', indexed: true, internalType: 'address' }
		],
		anonymous: false
	},

	// ── Read functions ──
	{
		type: 'function',
		name: 'owner',
		inputs: [],
		outputs: [{ name: '', type: 'address', internalType: 'address' }],
		stateMutability: 'view'
	},
	{
		type: 'function',
		name: 'invoiceVault',
		inputs: [],
		outputs: [{ name: '', type: 'address', internalType: 'contract IInvoiceVaultFP' }],
		stateMutability: 'view'
	},
	{
		type: 'function',
		name: 'creditOracle',
		inputs: [],
		outputs: [{ name: '', type: 'address', internalType: 'contract ICreditOracle' }],
		stateMutability: 'view'
	},
	{
		type: 'function',
		name: 'BPS',
		inputs: [],
		outputs: [{ name: '', type: 'uint128', internalType: 'uint128' }],
		stateMutability: 'view'
	},
	{
		type: 'function',
		name: 'isFunded',
		inputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
		outputs: [{ name: '', type: 'bool', internalType: 'bool' }],
		stateMutability: 'view'
	},
	{
		type: 'function',
		name: 'settlementRequested',
		inputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
		outputs: [{ name: '', type: 'bool', internalType: 'bool' }],
		stateMutability: 'view'
	},
	{
		type: 'function',
		name: 'settlementReady',
		inputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
		outputs: [{ name: '', type: 'bool', internalType: 'bool' }],
		stateMutability: 'view'
	},
	{
		type: 'function',
		name: 'repayAmountPlain',
		inputs: [{ name: '', type: 'uint256', internalType: 'uint256' }],
		outputs: [{ name: '', type: 'uint128', internalType: 'uint128' }],
		stateMutability: 'view'
	},
	{
		type: 'function',
		name: 'getPositionMeta',
		inputs: [{ name: 'tokenId', type: 'uint256', internalType: 'uint256' }],
		outputs: [
			{ name: 'lender', type: 'address', internalType: 'address' },
			{ name: 'sme', type: 'address', internalType: 'address' },
			{ name: 'advanceRateBps', type: 'uint16', internalType: 'uint16' },
			{ name: 'discountRateBps', type: 'uint16', internalType: 'uint16' },
			{ name: 'fundedAt', type: 'uint256', internalType: 'uint256' },
			{ name: 'settled', type: 'bool', internalType: 'bool' }
		],
		stateMutability: 'view'
	},
	{
		type: 'function',
		name: 'getLenderPositions',
		inputs: [{ name: 'lender', type: 'address', internalType: 'address' }],
		outputs: [{ name: '', type: 'uint256[]', internalType: 'uint256[]' }],
		stateMutability: 'view'
	},
	{
		type: 'function',
		name: 'getEncryptedAdvance',
		inputs: [{ name: 'tokenId', type: 'uint256', internalType: 'uint256' }],
		outputs: [{ name: '', type: 'uint256', internalType: 'euint128' }],
		stateMutability: 'view'
	},
	{
		type: 'function',
		name: 'getEncryptedFee',
		inputs: [{ name: 'tokenId', type: 'uint256', internalType: 'uint256' }],
		outputs: [{ name: '', type: 'uint256', internalType: 'euint128' }],
		stateMutability: 'view'
	},
	{
		type: 'function',
		name: 'getEncryptedRepay',
		inputs: [{ name: 'tokenId', type: 'uint256', internalType: 'uint256' }],
		outputs: [{ name: '', type: 'uint256', internalType: 'euint128' }],
		stateMutability: 'view'
	},
	{
		type: 'function',
		name: 'getRepayAmount',
		inputs: [{ name: 'tokenId', type: 'uint256', internalType: 'uint256' }],
		outputs: [{ name: '', type: 'uint128', internalType: 'uint128' }],
		stateMutability: 'view'
	},

	// ── Write functions ──
	{
		type: 'function',
		name: 'fundInvoice',
		inputs: [
			{ name: 'tokenId', type: 'uint256', internalType: 'uint256' },
			{ name: 'advanceRateBps', type: 'uint16', internalType: 'uint16' },
			{ name: 'discountRateBps', type: 'uint16', internalType: 'uint16' }
		],
		outputs: [],
		stateMutability: 'nonpayable'
	},
	{
		type: 'function',
		name: 'requestSettlement',
		inputs: [{ name: 'tokenId', type: 'uint256', internalType: 'uint256' }],
		outputs: [],
		stateMutability: 'nonpayable'
	},
	{
		type: 'function',
		name: 'finalizeSettlement',
		inputs: [{ name: 'tokenId', type: 'uint256', internalType: 'uint256' }],
		outputs: [],
		stateMutability: 'nonpayable'
	},
	{
		type: 'function',
		name: 'repay',
		inputs: [{ name: 'tokenId', type: 'uint256', internalType: 'uint256' }],
		outputs: [],
		stateMutability: 'payable'
	},
	{
		type: 'function',
		name: 'transferOwnership',
		inputs: [{ name: 'newOwner', type: 'address', internalType: 'address' }],
		outputs: [],
		stateMutability: 'nonpayable'
	},

	// ── Receive ──
	{ type: 'receive', stateMutability: 'payable' }
] as const;
