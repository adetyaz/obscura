export const CredentialRegistryABI = [
	{
		inputs: [],
		stateMutability: 'nonpayable',
		type: 'constructor'
	},
	{
		inputs: [
			{ internalType: 'uint8', name: 'got', type: 'uint8' },
			{ internalType: 'uint8', name: 'expected', type: 'uint8' }
		],
		name: 'InvalidEncryptedInput',
		type: 'error'
	},
	{
		anonymous: false,
		inputs: [{ indexed: true, internalType: 'address', name: 'wallet', type: 'address' }],
		name: 'CredentialStored',
		type: 'event'
	},
	{
		anonymous: false,
		inputs: [{ indexed: true, internalType: 'address', name: 'wallet', type: 'address' }],
		name: 'KYBVerified',
		type: 'event'
	},
	{
		anonymous: false,
		inputs: [{ indexed: true, internalType: 'address', name: 'wallet', type: 'address' }],
		name: 'KYCVerified',
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
		name: 'getCredentialType',
		outputs: [{ internalType: 'enum CredentialRegistry.CredentialType', name: '', type: 'uint8' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'address', name: 'wallet', type: 'address' }],
		name: 'isVerified',
		outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'address', name: 'wallet', type: 'address' }],
		name: 'isVerifiedKYB',
		outputs: [{ internalType: 'bool', name: '', type: 'bool' }],
		stateMutability: 'view',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'address', name: 'wallet', type: 'address' }],
		name: 'isVerifiedKYC',
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
		inputs: [],
		name: 'selfVerify',
		outputs: [],
		stateMutability: 'nonpayable',
		type: 'function'
	},
	{
		inputs: [],
		name: 'selfVerifyKYC',
		outputs: [],
		stateMutability: 'nonpayable',
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
		inputs: [{ internalType: 'address', name: 'wallet', type: 'address' }],
		name: 'setVerifiedKYB',
		outputs: [],
		stateMutability: 'nonpayable',
		type: 'function'
	},
	{
		inputs: [{ internalType: 'address', name: 'wallet', type: 'address' }],
		name: 'setVerifiedKYC',
		outputs: [],
		stateMutability: 'nonpayable',
		type: 'function'
	},
	{
		inputs: [
			{
				components: [
					{ internalType: 'uint256', name: 'ctHash', type: 'uint256' },
					{ internalType: 'uint8', name: 'securityZone', type: 'uint8' },
					{ internalType: 'uint8', name: 'utype', type: 'uint8' },
					{ internalType: 'bytes', name: 'signature', type: 'bytes' }
				],
				internalType: 'struct InEuint128',
				name: 'encryptedCredential',
				type: 'tuple'
			}
		],
		name: 'storeCredential',
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
