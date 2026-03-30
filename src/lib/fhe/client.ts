import { cofhejs, Encryptable, type Permission } from 'cofhejs/web';
import { publicClient, getWalletClient } from '$lib/viem/client';

let initialized = false;

export async function initFhe() {
	if (initialized) return;

	const walletClient = getWalletClient();
	const result = await cofhejs.initializeWithViem({
		viemClient: publicClient,
		viemWalletClient: walletClient
	});

	if (!result.success) {
		throw new Error(`FHE init failed: ${result.error}`);
	}

	initialized = true;
}

export async function encryptUint128(value: bigint) {
	const result = await cofhejs.encrypt([Encryptable.uint128(value)]);
	if (!result.success) {
		throw new Error(`Encryption failed: ${result.error}`);
	}
	return result.data[0];
}

export async function getPermission(): Promise<Permission> {
	const result = cofhejs.getPermission();
	if (!result.success) {
		throw new Error(`Get permission failed: ${result.error}`);
	}
	return result.data;
}

export { cofhejs, Encryptable };
