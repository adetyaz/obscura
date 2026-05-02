import { createWalletClient, http } from 'viem';
import { privateKeyToAccount } from 'viem/accounts';
import { arbitrumSepolia } from 'viem/chains';
import { publicClient } from '$lib/viem/client';
import { financingPoolAbi } from '$lib/contracts/abis/FinancingPool';
import { ObscuraRepaymentGateABI } from '$lib/contracts/abis/ObscuraRepaymentGate';
import { ADDRESSES } from '$lib/contracts/addresses';

export function startRepaymentRelayer(params: {
	relayerPrivateKey: `0x${string}`;
	gateAddress: `0x${string}`;
	onRelayed?: (tokenId: bigint, txHash: `0x${string}`) => void;
	onError?: (error: unknown) => void;
}) {
	const account = privateKeyToAccount(params.relayerPrivateKey);
	const arbitrumClient = createWalletClient({
		chain: arbitrumSepolia,
		transport: http('https://sepolia-rollup.arbitrum.io/rpc'),
		account
	});

	return publicClient.watchContractEvent({
		address: ADDRESSES.FinancingPool,
		abi: financingPoolAbi,
		eventName: 'RepaymentReceived',
		onLogs: async (logs) => {
			for (const log of logs) {
				try {
					const tokenId = log.args.tokenId as bigint;
					const txHash = await arbitrumClient.writeContract({
						address: params.gateAddress,
						abi: ObscuraRepaymentGateABI,
						functionName: 'confirmRepayment',
						args: [tokenId]
					});

					params.onRelayed?.(tokenId, txHash);
				} catch (error) {
					params.onError?.(error);
				}
			}
		}
	});
}
