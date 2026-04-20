import { publicClient, getWalletClient } from '$lib/viem/client';
import { InvoiceVaultABI } from '$lib/contracts/abis/InvoiceVault';
import { CreditOracleABI } from '$lib/contracts/abis/CreditOracle';
import { financingPoolAbi } from '$lib/contracts/abis/FinancingPool';
import { ADDRESSES } from '$lib/contracts/addresses';
import { PoolTier, PositionStatus } from '$lib/stores/sme.svelte';
import type { PoolTierValue, PositionStatusValue } from '$lib/stores/sme.svelte';

export interface MarketplaceInvoice {
	tokenId: bigint;
	submitter: string;
	submittedAt: bigint;
	active: boolean;
	scoreReady: boolean;
	score: number | null;
	funded: boolean;
	poolTier: PoolTierValue; // Wave 2
}

export interface LenderPosition {
	tokenId: bigint;
	sme: string;
	advanceRateBps: number;
	discountRateBps: number;
	fundedAt: bigint;
	maturityDate: bigint; // Wave 2
	gracePeriodEnd: bigint; // Wave 2
	settled: boolean;
	positionStatus: PositionStatusValue; // Wave 2
	score: number | null;
	poolTier: PoolTierValue; // Wave 2
}

let listings = $state<MarketplaceInvoice[]>([]);
let positions = $state<LenderPosition[]>([]);
let isLoading = $state(false);
let isFunding = $state(false);

async function loadListings() {
	isLoading = true;

	try {
		const nextTokenId = await publicClient.readContract({
			address: ADDRESSES.InvoiceVault,
			abi: InvoiceVaultABI,
			functionName: 'nextTokenId'
		});

		const items: MarketplaceInvoice[] = [];

		for (let i = 1n; i < nextTokenId; i++) {
			const [submitter, submittedAt, active] = await publicClient.readContract({
				address: ADDRESSES.InvoiceVault,
				abi: InvoiceVaultABI,
				functionName: 'getInvoiceMeta',
				args: [i]
			});

			if (!active) continue;

			const funded = await publicClient.readContract({
				address: ADDRESSES.FinancingPool,
				abi: financingPoolAbi,
				functionName: 'isFunded',
				args: [i]
			});

			const scoreReady = await publicClient.readContract({
				address: ADDRESSES.CreditOracle,
				abi: CreditOracleABI,
				functionName: 'scoreReady',
				args: [i]
			});

			let score: number | null = null;
			if (scoreReady) {
				score = await publicClient.readContract({
					address: ADDRESSES.CreditOracle,
					abi: CreditOracleABI,
					functionName: 'getScore',
					args: [i]
				});
			}

			// Wave 2: read pool tier
			const poolTier = (await publicClient.readContract({
				address: ADDRESSES.InvoiceVault,
				abi: InvoiceVaultABI,
				functionName: 'getPoolTier',
				args: [i]
			})) as PoolTierValue;

			items.push({
				tokenId: i,
				submitter,
				submittedAt,
				active,
				scoreReady,
				score,
				funded,
				poolTier
			});
		}

		listings = items;
	} catch {
		listings = [];
	} finally {
		isLoading = false;
	}
}

async function loadPositions(lenderAddress: `0x${string}`) {
	try {
		const tokenIds = await publicClient.readContract({
			address: ADDRESSES.FinancingPool,
			abi: financingPoolAbi,
			functionName: 'getLenderPositions',
			args: [lenderAddress]
		});

		const items: LenderPosition[] = [];

		for (const tokenId of tokenIds) {
			const [
				,
				sme,
				advanceRateBps,
				discountRateBps,
				fundedAt,
				posMaturityDate,
				posGracePeriodEnd,
				settled,
				posStatus
			] = await publicClient.readContract({
				address: ADDRESSES.FinancingPool,
				abi: financingPoolAbi,
				functionName: 'getPositionMeta',
				args: [tokenId]
			});

			// Wave 2: pool tier
			const poolTier = (await publicClient.readContract({
				address: ADDRESSES.InvoiceVault,
				abi: InvoiceVaultABI,
				functionName: 'getPoolTier',
				args: [tokenId]
			})) as PoolTierValue;

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

			items.push({
				tokenId,
				sme,
				advanceRateBps,
				discountRateBps,
				fundedAt,
				maturityDate: posMaturityDate,
				gracePeriodEnd: posGracePeriodEnd,
				settled,
				positionStatus: Number(posStatus) as PositionStatusValue,
				score,
				poolTier
			});
		}

		positions = items;
	} catch {
		positions = [];
	}
}

async function fundInvoice(
	tokenId: bigint,
	advanceRateBps: number,
	discountRateBps: number,
	tenorDays: number
): Promise<`0x${string}`> {
	isFunding = true;
	try {
		const walletClient = getWalletClient();
		const [account] = await walletClient.getAddresses();

		const hash = await walletClient.writeContract({
			address: ADDRESSES.FinancingPool,
			abi: financingPoolAbi,
			functionName: 'fundInvoice',
			args: [tokenId, advanceRateBps, discountRateBps, tenorDays],
			account
		});

		await publicClient.waitForTransactionReceipt({ hash });
		return hash;
	} finally {
		isFunding = false;
	}
}

// Wave 2: Enter grace period for an overdue position (callable by anyone after maturity)
async function enterGracePeriod(tokenId: bigint): Promise<`0x${string}`> {
	const walletClient = getWalletClient();
	const [account] = await walletClient.getAddresses();

	const hash = await walletClient.writeContract({
		address: ADDRESSES.FinancingPool,
		abi: financingPoolAbi,
		functionName: 'enterGracePeriod',
		args: [tokenId],
		account
	});

	await publicClient.waitForTransactionReceipt({ hash });
	return hash;
}

// Wave 2: Trigger escalation on a position past grace period (lender only)
async function triggerEscalation(tokenId: bigint): Promise<`0x${string}`> {
	const walletClient = getWalletClient();
	const [account] = await walletClient.getAddresses();

	const hash = await walletClient.writeContract({
		address: ADDRESSES.FinancingPool,
		abi: financingPoolAbi,
		functionName: 'triggerEscalation',
		args: [tokenId],
		account
	});

	await publicClient.waitForTransactionReceipt({ hash });
	return hash;
}

function reset() {
	listings = [];
	positions = [];
	isLoading = false;
	isFunding = false;
}

export const lenderStore = {
	get listings() {
		return listings;
	},
	get positions() {
		return positions;
	},
	get isLoading() {
		return isLoading;
	},
	get isFunding() {
		return isFunding;
	},
	loadListings,
	loadPositions,
	fundInvoice,
	enterGracePeriod,
	triggerEscalation,
	reset
};
