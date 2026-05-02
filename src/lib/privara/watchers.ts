import { publicClient } from '$lib/viem/client';
import { financingPoolAbi } from '$lib/contracts/abis/FinancingPool';
import { ADDRESSES } from '$lib/contracts/addresses';
import { createEscrow } from '$lib/privara/client';

export type ResolveFundedAmount = (params: {
	tokenId: bigint;
	smeAddress: `0x${string}`;
	advanceRateBps: number;
	discountRateBps: number;
}) => Promise<bigint> | bigint;

const defaultResolveAmount: ResolveFundedAmount = () => 0n;

export function startInvoiceFundedWatcher(options?: {
	resolveAmountUSDC?: ResolveFundedAmount;
	onEscrowCreated?: (params: { tokenId: bigint; escrowId: bigint; txId: string }) => void;
	onError?: (error: unknown) => void;
}) {
	const resolveAmountUSDC = options?.resolveAmountUSDC ?? defaultResolveAmount;

	return publicClient.watchContractEvent({
		address: ADDRESSES.FinancingPool,
		abi: financingPoolAbi,
		eventName: 'InvoiceFunded',
		onLogs: async (logs) => {
			for (const log of logs) {
				try {
					const tokenId = log.args.tokenId as bigint;
					const smeAddress = log.args.smeAddress as `0x${string}`;
					const advanceRateBps = Number(log.args.advanceRateBps as number);
					const discountRateBps = Number(log.args.discountRateBps as number);
					const amountUSDC = await resolveAmountUSDC({
						tokenId,
						smeAddress,
						advanceRateBps,
						discountRateBps
					});

					const result = await createEscrow({
						recipientAddress: smeAddress,
						amountUSDC,
						tokenId
					});

					options?.onEscrowCreated?.({ tokenId, escrowId: result.escrowId, txId: result.txId });
				} catch (error) {
					options?.onError?.(error);
				}
			}
		}
	});
}

export function startRepaymentEventWatcher(options?: {
	onRepayment?: (params: { tokenId: bigint; sme: `0x${string}`; amount: bigint }) => void;
	onError?: (error: unknown) => void;
}) {
	return publicClient.watchContractEvent({
		address: ADDRESSES.FinancingPool,
		abi: financingPoolAbi,
		eventName: 'RepaymentReceived',
		onLogs: async (logs) => {
			for (const log of logs) {
				try {
					options?.onRepayment?.({
						tokenId: log.args.tokenId as bigint,
						sme: log.args.sme as `0x${string}`,
						amount: log.args.amount as bigint
					});
				} catch (error) {
					options?.onError?.(error);
				}
			}
		}
	});
}
