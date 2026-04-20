import { getWalletClient, publicClient, getCofheClient } from '$lib/viem/client';
import { initFhe, Encryptable } from '$lib/fhe/client';
import { InvoiceVaultABI } from '$lib/contracts/abis/InvoiceVault';
import { CreditOracleABI } from '$lib/contracts/abis/CreditOracle';
import { financingPoolAbi } from '$lib/contracts/abis/FinancingPool';
import { ADDRESSES } from '$lib/contracts/addresses';

// Wave 2: PoolTier enum values (mirrors Solidity enum)
export const PoolTier = { INSTITUTIONAL: 0, GOVERNMENT: 1, RETAIL: 2 } as const;
export type PoolTierValue = (typeof PoolTier)[keyof typeof PoolTier];

// Wave 2: PositionStatus enum values (mirrors Solidity enum)
export const PositionStatus = { ACTIVE: 0, REPAID: 1, GRACE: 2, ESCALATED: 3 } as const;
export type PositionStatusValue = (typeof PositionStatus)[keyof typeof PositionStatus];

export interface InvoiceItem {
	tokenId: bigint;
	submitter: string;
	submittedAt: bigint;
	active: boolean;
	scoreRequested: boolean;
	scoreReady: boolean;
	score: number | null;
	poolTier: PoolTierValue; // Wave 2
	funded: boolean;
	settled: boolean;
	fundedAt: bigint | null;
	lender: string | null;
	advanceRateBps: number | null;
	discountRateBps: number | null;
	maturityDate: bigint | null; // Wave 2
	gracePeriodEnd: bigint | null; // Wave 2
	positionStatus: PositionStatusValue | null; // Wave 2
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
				let maturityDate: bigint | null = null;
				let gracePeriodEnd: bigint | null = null;
				let positionStatus: PositionStatusValue | null = null;
				let settlementRequested = false;
				let settlementReady = false;
				let repayAmount: bigint | null = null;

				// Wave 2: read pool tier
				const poolTier = (await publicClient.readContract({
					address: ADDRESSES.InvoiceVault,
					abi: InvoiceVaultABI,
					functionName: 'getPoolTier',
					args: [tokenId]
				})) as PoolTierValue;

				if (funded) {
					const [
						posLender,
						,
						posAdvance,
						posDiscount,
						posFundedAt,
						posMaturityDate,
						posGracePeriodEnd,
						posSettled,
						posStatus
					] = await publicClient.readContract({
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
					maturityDate = posMaturityDate;
					gracePeriodEnd = posGracePeriodEnd;
					positionStatus = Number(posStatus) as PositionStatusValue;

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
					poolTier,
					funded,
					settled,
					fundedAt,
					lender,
					advanceRateBps,
					discountRateBps,
					maturityDate,
					gracePeriodEnd,
					positionStatus,
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
	await initFhe();
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

async function finalizeSettlement(tokenId: bigint): Promise<`0x${string}`> {
	const walletClient = getWalletClient();
	const [account] = await walletClient.getAddresses();
	await initFhe();
	const cofheClient = await getCofheClient();

	const ctHash = await publicClient.readContract({
		address: ADDRESSES.FinancingPool,
		abi: financingPoolAbi,
		functionName: 'getEncryptedRepay',
		args: [tokenId]
	});

	const result = await cofheClient.decryptForTx(ctHash).withoutPermit().execute();

	const { request } = await publicClient.simulateContract({
		address: ADDRESSES.FinancingPool,
		abi: financingPoolAbi,
		functionName: 'finalizeSettlement',
		args: [tokenId, result.decryptedValue as bigint, result.signature as `0x${string}`],
		account
	});

	const hash = await walletClient.writeContract(request);
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

// Wave 2: Submit a government invoice (KYB required, encrypts gov ref)
async function submitGovernmentInvoice(
	amountUsdc: bigint,
	dueDateUnix: bigint,
	encryptedBuyer: `0x${string}`,
	govRefValue: bigint
): Promise<`0x${string}`> {
	const walletClient = getWalletClient();
	const [account] = await walletClient.getAddresses();
	await initFhe();
	const cofheClient = await getCofheClient();

	const [encAmount, encDueDate, encGovRef] = await cofheClient
		.encryptInputs([
			Encryptable.uint128(amountUsdc),
			Encryptable.uint128(dueDateUnix),
			Encryptable.uint128(govRefValue)
		])
		.execute();

	const { request } = await publicClient.simulateContract({
		address: ADDRESSES.InvoiceVault,
		abi: InvoiceVaultABI,
		functionName: 'submitGovernmentInvoice',
		// eslint-disable-next-line @typescript-eslint/no-explicit-any
		args: [encAmount as any, encDueDate as any, encryptedBuyer, encGovRef as any],
		account
	});

	const hash = await walletClient.writeContract(request);
	await publicClient.waitForTransactionReceipt({ hash });
	return hash;
}

// Wave 2: Get the advance rate tier for a borrower (85 default, 90 after 3+ repayments)
async function getAdvanceRateTier(address: `0x${string}`): Promise<number> {
	return await publicClient.readContract({
		address: ADDRESSES.CreditOracle,
		abi: CreditOracleABI,
		functionName: 'getAdvanceRateTier',
		args: [address]
	});
}

// Wave 2: Get repayment count for a borrower
async function getRepaymentCount(address: `0x${string}`): Promise<number> {
	return await publicClient.readContract({
		address: ADDRESSES.CreditOracle,
		abi: CreditOracleABI,
		functionName: 'repaymentCounts',
		args: [address]
	});
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
	submitGovernmentInvoice,
	getAdvanceRateTier,
	getRepaymentCount,
	reset
};
