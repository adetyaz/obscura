export const CredentialRegistryABI = [
	{
		inputs: [],
		stateMutability: 'nonpayable',
		type: 'constructor'
	},
	{
		anonymous: false,
		inputs: [{ indexed: true, internalType: 'address', name: 'wallet', type: 'address' }],
		name: 'CredentialStored',
		type: 'event'
	},
	{
		anonymous: false,
		inputs: [
			{ indexed: true, internalType: 'address', name: 'wallet', type: 'address' },
			{ indexed: false, internalType: 'bool', name: 'status', type: 'bool' }
		],
		name: 'VerificationUpdated',
		type: 'event'
	},
	{
		inputs: [{ internalType: 'address', name: 'wallet', type: 'address' }],
		name: 'isVerified',
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
		inputs: [
			{ internalType: 'address', name: 'wallet', type: 'address' },
			{ internalType: 'bool', name: 'status', type: 'bool' }
		],
		name: 'setVerified',
		outputs: [],
		stateMutability: 'nonpayable',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'address', name: 'newOwner', type: 'address' }],
		name: 'transferOwnership',
		outputs: [],
		stateMutability: 'nonpayable',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'address', name: '', type: 'address' }],
		name: 'verified',
		outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
		stateMutability: 'view',
		type: 'function'
	}
] as const;
