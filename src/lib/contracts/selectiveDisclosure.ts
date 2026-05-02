import { getWalletClient, publicClient } from '$lib/viem/client';
import { ADDRESSES } from '$lib/contracts/addresses';
import { SelectiveDisclosureABI } from '$lib/contracts/abis/SelectiveDisclosure';

export async function requestProof(params: {
	proofType: 0 | 1;
	threshold: bigint;
}): Promise<`0x${string}`> {
	if (!('SelectiveDisclosure' in ADDRESSES) || !ADDRESSES.SelectiveDisclosure) {
		throw new Error('Missing ADDRESSES.SelectiveDisclosure');
	}

	const walletClient = getWalletClient();
	const [account] = await walletClient.getAddresses();

	const hash = await walletClient.writeContract({
		address: ADDRESSES.SelectiveDisclosure,
		abi: SelectiveDisclosureABI,
		functionName: 'requestProof',
		args: [params.proofType, params.threshold],
		account
	});

	await publicClient.waitForTransactionReceipt({ hash });
	return hash;
}

export function watchProofFulfilled(
	requestId: `0x${string}`,
	onResult: (result: boolean, txHash: `0x${string}`) => void
) {
	if (!('SelectiveDisclosure' in ADDRESSES) || !ADDRESSES.SelectiveDisclosure) {
		throw new Error('Missing ADDRESSES.SelectiveDisclosure');
	}

	return publicClient.watchContractEvent({
		address: ADDRESSES.SelectiveDisclosure,
		abi: SelectiveDisclosureABI,
		eventName: 'ProofFulfilled',
		args: { requestId },
		onLogs: (logs) => {
			for (const log of logs) {
				onResult(Boolean(log.args.result), log.transactionHash);
			}
		}
	});
}

export function downloadProof(proof: {
	requestId: string;
	proofType: string;
	threshold: string;
	result: boolean;
	blockNumber: bigint;
	txHash: string;
}) {
	const content = JSON.stringify(
		{
			protocol: 'Obscura',
			version: 'Wave 3',
			...proof,
			generatedAt: new Date().toISOString()
		},
		null,
		2
	);

	const blob = new Blob([content], { type: 'application/json' });
	const url = URL.createObjectURL(blob);
	const a = document.createElement('a');
	a.href = url;
	a.download = `obscura-proof-${proof.requestId.slice(0, 8)}.json`;
	a.click();
	URL.revokeObjectURL(url);
}
