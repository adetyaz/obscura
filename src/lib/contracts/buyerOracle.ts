import { keccak256, encodePacked } from 'viem';
import { getWalletClient, publicClient } from '$lib/viem/client';
import { ADDRESSES } from '$lib/contracts/addresses';
import { BuyerOracleABI } from '$lib/contracts/abis/BuyerOracle';

export function buyerKeyFromTokenId(tokenId: bigint): `0x${string}` {
	return keccak256(encodePacked(['uint256'], [tokenId]));
}

export async function requestBuyerScore(params: {
	tokenId: bigint;
	jurisdiction: 'NG' | 'UK';
}): Promise<`0x${string}`> {
	const buyerOracle = ADDRESSES.BuyerOracle;
	if (!buyerOracle || buyerOracle === '0x0000000000000000000000000000000000000000') {
		throw new Error('Missing BuyerOracle address');
	}

	const walletClient = getWalletClient();
	const [account] = await walletClient.getAddresses();
	const buyerKey = buyerKeyFromTokenId(params.tokenId);

	const hash = await walletClient.writeContract({
		address: buyerOracle,
		abi: BuyerOracleABI,
		functionName: 'requestBuyerScore',
		args: [buyerKey, params.jurisdiction],
		account
	});

	await publicClient.waitForTransactionReceipt({ hash });
	return hash;
}

export function watchBuyerScoreUpdated(
	tokenId: bigint,
	onUpdated: (updatedAt: bigint, txHash: `0x${string}`) => void
) {
	const buyerOracle = ADDRESSES.BuyerOracle;
	if (!buyerOracle || buyerOracle === '0x0000000000000000000000000000000000000000') {
		throw new Error('Missing BuyerOracle address');
	}

	const buyerKey = buyerKeyFromTokenId(tokenId);

	return publicClient.watchContractEvent({
		address: buyerOracle,
		abi: BuyerOracleABI,
		eventName: 'BuyerScoreUpdated',
		args: { buyerKey },
		onLogs: (logs) => {
			for (const log of logs) {
				onUpdated(log.args.timestamp as bigint, log.transactionHash);
			}
		}
	});
}
