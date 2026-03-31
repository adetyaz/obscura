import { Encryptable } from '@cofhe/sdk';
import { publicClient, getWalletClient, getCofheClient } from '$lib/viem/client';

export type InEuint128Arg = {
	ctHash: bigint;
	securityZone: number;
	utype: number;
	signature: `0x${string}`;
};

export async function initFhe() {
	const walletClient = getWalletClient();
	const cofheClient = await getCofheClient();
	// eslint-disable-next-line @typescript-eslint/no-explicit-any
	await cofheClient.connect(publicClient as any, walletClient as any);
}

export async function encryptUint128(value: bigint): Promise<InEuint128Arg> {
	const cofheClient = await getCofheClient();
	const [encrypted] = await cofheClient.encryptInputs([Encryptable.uint128(value)]).execute();
	return encrypted as unknown as InEuint128Arg;
}

export { Encryptable };
