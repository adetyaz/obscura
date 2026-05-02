import { Encryptable } from '@cofhe/sdk';
import { chains } from '@cofhe/sdk/chains';
import { createCofheClient, createCofheConfig } from '@cofhe/sdk/web';
import { createPublicClient, createWalletClient, custom, http } from 'viem';
import { arbitrumSepolia } from 'viem/chains';
import { setEscrowIdForToken } from '$lib/privara/escrowMap';

type InEncryptedInput = {
	ctHash: bigint;
	securityZone: number;
	utype: number;
	signature: `0x${string}`;
};

const ESCROW_ABI = [
	{
		name: 'create',
		type: 'function',
		stateMutability: 'nonpayable',
		inputs: [
			{
				name: 'encryptedOwner',
				type: 'tuple',
				components: [
					{ name: 'ctHash', type: 'uint256' },
					{ name: 'securityZone', type: 'int32' },
					{ name: 'utype', type: 'uint8' },
					{ name: 'signature', type: 'bytes' }
				]
			},
			{
				name: 'encryptedAmount',
				type: 'tuple',
				components: [
					{ name: 'ctHash', type: 'uint256' },
					{ name: 'securityZone', type: 'int32' },
					{ name: 'utype', type: 'uint8' },
					{ name: 'signature', type: 'bytes' }
				]
			},
			{ name: 'resolver', type: 'address' },
			{ name: 'resolverData', type: 'bytes' }
		],
		outputs: [{ name: 'escrowId', type: 'uint256' }]
	}
] as const;

const REINEIRA_ESCROW_ADDRESS = import.meta.env.VITE_REINEIRA_ESCROW_ADDRESS as `0x${string}`;
const REINEIRA_GATE_ADDRESS = import.meta.env.VITE_GATE_ADDRESS as `0x${string}`;

const arbPublicClient = createPublicClient({
	chain: arbitrumSepolia,
	transport: http('https://sepolia-rollup.arbitrum.io/rpc')
});

let _cofheClient: Awaited<ReturnType<typeof createCofheClient>> | null = null;

function getArbWalletClient() {
	if (typeof window === 'undefined' || !window.ethereum) {
		throw new Error('MetaMask not found');
	}
	return createWalletClient({
		chain: arbitrumSepolia,
		transport: custom(window.ethereum)
	});
}

async function getArbCofheClient() {
	if (_cofheClient) return _cofheClient;
	const config = createCofheConfig({ supportedChains: [chains.arbitrumSepolia] });
	_cofheClient = createCofheClient(config);
	await _cofheClient.connect(
		// eslint-disable-next-line @typescript-eslint/no-explicit-any
		arbPublicClient as any,
		// eslint-disable-next-line @typescript-eslint/no-explicit-any
		getArbWalletClient() as any
	);
	return _cofheClient;
}

function encodeTokenId(tokenId: bigint): `0x${string}` {
	return `0x${tokenId.toString(16).padStart(64, '0')}` as `0x${string}`;
}

export async function createEscrow(params: {
	recipientAddress: `0x${string}`;
	amountUSDC: bigint;
	tokenId: bigint;
	gateAddress?: `0x${string}`;
}): Promise<{ success: boolean; txId: `0x${string}`; escrowId: bigint }> {
	if (!REINEIRA_ESCROW_ADDRESS) {
		throw new Error('Missing VITE_REINEIRA_ESCROW_ADDRESS');
	}

	const walletClient = getArbWalletClient();
	const [account] = await walletClient.getAddresses();
	const cofheClient = await getArbCofheClient();
	const resolver = params.gateAddress ?? REINEIRA_GATE_ADDRESS;

	if (!resolver) {
		throw new Error('Missing gate address. Set VITE_GATE_ADDRESS or pass gateAddress');
	}

	const [encOwner, encAmount] = (await cofheClient
		.encryptInputs([
			Encryptable.address(params.recipientAddress),
			Encryptable.uint64(params.amountUSDC)
		])
		.execute()) as unknown as [InEncryptedInput, InEncryptedInput];

	const resolverData = encodeTokenId(params.tokenId);

	const { result: escrowId, request } = await arbPublicClient.simulateContract({
		address: REINEIRA_ESCROW_ADDRESS,
		abi: ESCROW_ABI,
		functionName: 'create',
		args: [encOwner, encAmount, resolver, resolverData],
		account
	});

	const txId = await walletClient.writeContract(request);
	await arbPublicClient.waitForTransactionReceipt({ hash: txId });
	setEscrowIdForToken(params.tokenId, escrowId);

	console.log(`[Privara] Escrow created token=${params.tokenId.toString()} escrowId=${escrowId.toString()}`);

	return { success: true, txId, escrowId };
}

export async function disburseAdvance(
	recipientAddress: string,
	amountUSDC: bigint,
	tokenId = 0n
): Promise<{ success: boolean; txId: string }> {
	const result = await createEscrow({
		recipientAddress: recipientAddress as `0x${string}`,
		amountUSDC,
		tokenId
	});

	return { success: result.success, txId: result.txId };
}
