import { getWalletClient, publicClient } from '$lib/viem/client';
import { CredentialRegistryABI } from '$lib/contracts/abis/CredentialRegistry';
import { ADDRESSES } from '$lib/contracts/addresses';

const LS_ADDRESS = 'obscura:address';
const LS_ROLE = 'obscura:role';
const LS_VERIFIED = 'obscura:verified';

let address = $state<`0x${string}` | null>(null);
const isConnected = $derived(address !== null);
let isVerified = $state(false);
let isConnecting = $state(false);
let isRestored = $state(false);
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
		localStorage.setItem(LS_ADDRESS, account);
		await checkVerified();
	} finally {
		isConnecting = false;
	}
}

async function disconnect() {
	address = null;
	isVerified = false;
	role = null;
	localStorage.removeItem(LS_ADDRESS);
	localStorage.removeItem(LS_ROLE);
	localStorage.removeItem(LS_VERIFIED);
}

/** Called once on app mount — silently restores session from localStorage. */
async function restore() {
	if (typeof window === 'undefined') return;

	const saved = localStorage.getItem(LS_ADDRESS) as `0x${string}` | null;
	if (!saved) {
		isRestored = true;
		return;
	}

	// Restore immediately from storage — don't round-trip MetaMask which returns []
	// when locked, causing a false "revoked" signal that wipes the session.
	address = saved;
	const savedRole = localStorage.getItem(LS_ROLE) as 'sme' | 'lender' | null;
	if (savedRole) role = savedRole;
	isVerified = localStorage.getItem(LS_VERIFIED) === 'true';

	// Best-effort: check verified status. Failure is fine — user is still "connected".
	try {
		await checkVerified();
	} catch {
		// RPC unavailable or contract not deployed — session still valid
	} finally {
		isRestored = true;
	}
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
	localStorage.setItem(LS_VERIFIED, String(result));
}

function setRole(newRole: 'sme' | 'lender') {
	role = newRole;
	localStorage.setItem(LS_ROLE, newRole);
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
	get isRestored() {
		return isRestored;
	},
	get role() {
		return role;
	},
	connect,
	disconnect,
	checkVerified,
	setRole,
	restore
};
