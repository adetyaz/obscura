import { getWalletClient, publicClient, getCofheClient } from '$lib/viem/client';
import { InvoiceVaultABI } from '$lib/contracts/abis/InvoiceVault';
import { CreditOracleABI } from '$lib/contracts/abis/CreditOracle';
import { financingPoolAbi } from '$lib/contracts/abis/FinancingPool';
import { ADDRESSES } from '$lib/contracts/addresses';

export interface InvoiceItem {
	tokenId: bigint;
	submitter: string;
	submittedAt: bigint;
	active: boolean;
	scoreRequested: boolean;
	scoreReady: boolean;
	score: number | null;
	funded: boolean;
	settled: boolean;
	fundedAt: bigint | null;
	lender: string | null;
	advanceRateBps: number | null;
	discountRateBps: number | null;
	settlementRequested: boolean;
	settlementReady: boolean;
	repayAmount: bigint | null;
}

let invoices = $state<InvoiceItem[]>([]);
let isLoading = $state(false);

async function loadInvoices(address: `0x${string}`) {
	isLoading = true;

	try {
		const tokenIds = await publicClient.readContract({
			address: ADDRESSES.InvoiceVault,
			abi: InvoiceVaultABI,
			functionName: 'getUserInvoices',
			args: [address]
		});

		const items: InvoiceItem[] = await Promise.all(
			tokenIds.map(async (tokenId) => {
				const [submitter, submittedAt, active] = await publicClient.readContract({
					address: ADDRESSES.InvoiceVault,
					abi: InvoiceVaultABI,
					functionName: 'getInvoiceMeta',
					args: [tokenId]
				});

				const scoreRequested = await publicClient.readContract({
					address: ADDRESSES.CreditOracle,
					abi: CreditOracleABI,
					functionName: 'scoreRequested',
					args: [tokenId]
				});

				const scoreReady = await publicClient.readContract({
					address: ADDRESSES.CreditOracle,
					abi: CreditOracleABI,
					functionName: 'scoreReady',
					args: [tokenId]
				});

				let score: number | null = null;
				if (scoreReady) {
					score = await publicClient.readContract({
						address: ADDRESSES.CreditOracle,
						abi: CreditOracleABI,
						functionName: 'getScore',
						args: [tokenId]
					});
				}

				// Check funding status
				const funded = await publicClient.readContract({
					address: ADDRESSES.FinancingPool,
					abi: financingPoolAbi,
					functionName: 'isFunded',
					args: [tokenId]
				});

				let settled = false;
				let fundedAt: bigint | null = null;
				let lender: string | null = null;
				let advanceRateBps: number | null = null;
				let discountRateBps: number | null = null;
				let settlementRequested = false;
				let settlementReady = false;
				let repayAmount: bigint | null = null;

				if (funded) {
					const [posLender, , posAdvance, posDiscount, posFundedAt, posSettled] =
						await publicClient.readContract({
							address: ADDRESSES.FinancingPool,
							abi: financingPoolAbi,
							functionName: 'getPositionMeta',
							args: [tokenId]
						});

					lender = posLender;
					advanceRateBps = posAdvance;
					discountRateBps = posDiscount;
					fundedAt = posFundedAt;
					settled = posSettled;

					settlementRequested = await publicClient.readContract({
						address: ADDRESSES.FinancingPool,
						abi: financingPoolAbi,
						functionName: 'settlementRequested',
						args: [tokenId]
					});

					settlementReady = await publicClient.readContract({
						address: ADDRESSES.FinancingPool,
						abi: financingPoolAbi,
						functionName: 'settlementReady',
						args: [tokenId]
					});

					if (settlementReady) {
						repayAmount = await publicClient.readContract({
							address: ADDRESSES.FinancingPool,
							abi: financingPoolAbi,
							functionName: 'getRepayAmount',
							args: [tokenId]
						});
					}
				}

				return {
					tokenId,
					submitter,
					submittedAt,
					active,
					scoreRequested,
					scoreReady,
					score,
					funded,
					settled,
					fundedAt,
					lender,
					advanceRateBps,
					discountRateBps,
					settlementRequested,
					settlementReady,
					repayAmount
				};
			})
		);

		invoices = items;
	} catch {
		invoices = [];
	} finally {
		isLoading = false;
	}
}

async function requestScore(tokenId: bigint): Promise<`0x${string}`> {
	const walletClient = getWalletClient();
	const [account] = await walletClient.getAddresses();

	const { request } = await publicClient.simulateContract({
		address: ADDRESSES.CreditOracle,
		abi: CreditOracleABI,
		functionName: 'requestScore',
		args: [tokenId],
		account
	});

	const hash = await walletClient.writeContract(request);
	await publicClient.waitForTransactionReceipt({ hash });
	return hash;
}

async function finalizeScore(tokenId: bigint): Promise<`0x${string}`> {
	const walletClient = getWalletClient();
	const [account] = await walletClient.getAddresses();
	const cofheClient = await getCofheClient();

	// Fetch the ciphertext handle from the contract
	const ctHash = await publicClient.readContract({
		address: ADDRESSES.CreditOracle,
		abi: CreditOracleABI,
		functionName: 'getEncryptedScoreHandle',
		args: [tokenId]
	});

	// Decrypt off-chain and get the Threshold Network signature for on-chain verification
	const result = await cofheClient.decryptForTx(ctHash).withoutPermit().execute();

	const { request } = await publicClient.simulateContract({
		address: ADDRESSES.CreditOracle,
		abi: CreditOracleABI,
		functionName: 'finalizeScore',
		args: [tokenId, Number(result.decryptedValue), result.signature as `0x${string}`],
		account
	});

	const hash = await walletClient.writeContract(request);
	await publicClient.waitForTransactionReceipt({ hash });
	return hash;
}

async function requestSettlement(tokenId: bigint): Promise<`0x${string}`> {
	const walletClient = getWalletClient();
	const [account] = await walletClient.getAddresses();

	const hash = await walletClient.writeContract({
		address: ADDRESSES.FinancingPool,
		abi: financingPoolAbi,
		functionName: 'requestSettlement',
		args: [tokenId],
		account
	});

	await publicClient.waitForTransactionReceipt({ hash });
	return hash;
}

async function finalizeSettlement(
	tokenId: bigint,
	decryptedRepay: bigint,
	signature: `0x${string}`
): Promise<`0x${string}`> {
	const walletClient = getWalletClient();
	const [account] = await walletClient.getAddresses();

	const hash = await walletClient.writeContract({
		address: ADDRESSES.FinancingPool,
		abi: financingPoolAbi,
		functionName: 'finalizeSettlement',
		args: [tokenId, decryptedRepay, signature],
		account
	});

	await publicClient.waitForTransactionReceipt({ hash });
	return hash;
}

async function repay(tokenId: bigint, amount: bigint): Promise<`0x${string}`> {
	const walletClient = getWalletClient();
	const [account] = await walletClient.getAddresses();

	const hash = await walletClient.writeContract({
		address: ADDRESSES.FinancingPool,
		abi: financingPoolAbi,
		functionName: 'repay',
		args: [tokenId],
		account,
		value: amount
	});

	await publicClient.waitForTransactionReceipt({ hash });
	return hash;
}

function reset() {
	invoices = [];
	isLoading = false;
}

export const smeStore = {
	get invoices() {
		return invoices;
	},
	get isLoading() {
		return isLoading;
	},
	loadInvoices,
	requestScore,
	finalizeScore,
	requestSettlement,
	finalizeSettlement,
	repay,
	reset
};
