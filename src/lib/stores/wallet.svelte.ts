import { getWalletClient, publicClient } from '$lib/viem/client';
import { CredentialRegistryABI } from '$lib/contracts/abis/CredentialRegistry';
import { ADDRESSES } from '$lib/contracts/addresses';

let address = $state<`0x${string}` | null>(null);
const isConnected = $derived(address !== null);
let isVerified = $state(false);
let isConnecting = $state(false);
let role = $state<'sme' | 'lender' | null>(null);

async function connect() {
	if (typeof window === 'undefined' || !window.ethereum) {
		throw new Error('MetaMask not found');
	}

	isConnecting = true;
	try {
		const walletClient = getWalletClient();
		const [account] = await walletClient.requestAddresses();
		address = account;
		await checkVerified();
	} finally {
		isConnecting = false;
	}
}

async function disconnect() {
	address = null;
	isVerified = false;
	role = null;
}

async function checkVerified() {
	if (!address) return;

	const result = await publicClient.readContract({
		address: ADDRESSES.CredentialRegistry,
		abi: CredentialRegistryABI,
		functionName: 'isVerified',
		args: [address]
	});

	isVerified = result;
}

function setRole(newRole: 'sme' | 'lender') {
	role = newRole;
}

export const wallet = {
	get address() {
		return address;
	},
	get isConnected() {
		return isConnected;
	},
	get isVerified() {
		return isVerified;
	},
	get isConnecting() {
		return isConnecting;
	},
	get role() {
		return role;
	},
	connect,
	disconnect,
	checkVerified,
	setRole
};
