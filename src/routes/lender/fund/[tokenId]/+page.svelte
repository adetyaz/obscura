<script lang="ts">
	import { page } from '$app/stores';
	import { resolve } from '$app/paths';
	import { lenderStore } from '$lib/stores/lender.svelte';
	import { wallet } from '$lib/stores/wallet.svelte';
	import { disburseAdvance } from '$lib/privara/client';

	const tokenIdParam = $derived($page.params.tokenId ?? '0');
	const tokenId = $derived(BigInt(tokenIdParam));
	const invoice = $derived(lenderStore.listings.find((l) => l.tokenId === tokenId) ?? null);

	let advanceRateBps = $state(8500);
	let discountRateBps = $state(200);
	let step = $state('');
	let error = $state('');
	let isProcessing = $state(false);
	let funded = $state(false);
	let txHash = $state<`0x${string}` | null>(null);

	const EXPLORER = 'https://sepolia.basescan.org/tx/';

	function scoreTier(score: number): string {
		if (score >= 75) return 'LOW RISK';
		if (score >= 40) return 'MEDIUM';
		return 'HIGH RISK';
	}

	function scoreGrade(score: number): string {
		if (score >= 85) return 'A+';
		if (score >= 75) return 'A-';
		if (score >= 60) return 'B+';
		if (score >= 50) return 'B-';
		return 'C';
	}

	function scoreColor(score: number): string {
		if (score >= 75) return 'text-teal';
		if (score >= 40) return 'text-ink';
		return 'text-accent';
	}

	function formatDate(ts: bigint): string {
		return new Date(Number(ts) * 1000).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric'
		});
	}

	function maturityDate(ts: bigint): string {
		return new Date(Number(ts) * 1000 + 90 * 24 * 60 * 60 * 1000).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric'
		});
	}

	function formatTokenId(id: bigint): string {
		return id.toString().padStart(4, '0');
	}

	async function fundPosition() {
		if (!invoice || isProcessing) return;

		isProcessing = true;
		error = '';

		try {
			step = 'Submitting funding transaction…';
			const hash = await lenderStore.fundInvoice(invoice.tokenId, advanceRateBps, discountRateBps);
			txHash = hash;

			step = 'Triggering USDC disbursement via Privara…';
			await disburseAdvance(invoice.submitter, 0n);

			step = 'Invoice funded successfully!';
			funded = true;
		} catch (err) {
			error = err instanceof Error ? err.message : 'Funding failed';
			step = '';
		} finally {
			isProcessing = false;
		}
	}
</script>

<div class="min-h-screen bg-paper px-8 py-10">
	<!-- Nav -->
	<div class="mb-8 flex items-center gap-3">
		<a
			href={resolve('/lender')}
			class="font-mono text-xs tracking-widest text-muted hover:text-ink"
		>
			← LENDER MARKETPLACE
		</a>
		<span class="font-mono text-xs text-border">/</span>
		<span class="font-mono text-xs tracking-widest text-ink">FUND POSITION</span>
	</div>

	{#if !invoice}
		<div class="border border-border p-8">
			<p class="font-mono text-xs tracking-widest text-muted">
				INVOICE [{tokenIdParam.padStart(4, '0')}] NOT FOUND IN MARKETPLACE
			</p>
			<p class="mt-2 font-mono text-[10px] text-muted">
				This invoice may have already been funded or is no longer available.
			</p>
			<a
				href={resolve('/lender')}
				class="mt-4 inline-block border border-ink px-4 py-2 font-mono text-xs tracking-widest text-ink hover:bg-ink hover:text-paper"
			>
				BACK TO MARKETPLACE
			</a>
		</div>
	{:else}
		<!-- Token heading -->
		<div class="mb-8">
			<p class="font-mono text-[10px] tracking-widest text-muted">INVOICE TOKEN</p>
			<h1 class="font-display text-4xl text-ink">
				[{formatTokenId(invoice.tokenId)}]
				<span class="text-muted">Corporate Invoice</span>
			</h1>
			<div class="mt-2 flex items-center gap-4">
				{#if invoice.funded}
					<span
						class="border border-muted px-2 py-0.5 font-mono text-[10px] tracking-widest text-muted"
					>
						FUNDED
					</span>
				{:else}
					<span
						class="border border-teal px-2 py-0.5 font-mono text-[10px] tracking-widest text-teal"
					>
						AVAILABLE
					</span>
				{/if}
				{#if invoice.scoreReady && invoice.score !== null}
					<span class="font-mono text-[10px] tracking-widest text-muted">
						TIER {scoreGrade(invoice.score)} · {scoreTier(invoice.score)}
					</span>
				{/if}
			</div>
		</div>

		<div class="grid grid-cols-3 gap-6">
			<!-- Left: Asset info + terms -->
			<div class="col-span-2 space-y-6">
				<!-- Asset Composition -->
				<div class="border border-border p-6">
					<p class="mb-4 font-mono text-[10px] tracking-widest text-muted">ASSET COMPOSITION</p>
					<div class="grid grid-cols-2 gap-4">
						<div class="border border-border p-4">
							<p class="font-mono text-[10px] tracking-widest text-muted">INVOICE AMOUNT</p>
							<p class="mt-1 font-mono text-sm text-muted">●●●●●● CONFIDENTIAL</p>
							<p class="mt-0.5 font-mono text-[10px] text-muted">FHE ENCRYPTED</p>
						</div>
						<div class="border border-border p-4">
							<p class="font-mono text-[10px] tracking-widest text-muted">BUYER</p>
							<p class="mt-1 font-mono text-sm text-muted">●●●●●● CONFIDENTIAL</p>
							<p class="mt-0.5 font-mono text-[10px] text-muted">PRIVACY PRESERVED</p>
						</div>
						<div class="border border-border p-4">
							<p class="font-mono text-[10px] tracking-widest text-muted">INVOICE DATE</p>
							<p class="mt-1 font-mono text-sm text-ink">{formatDate(invoice.submittedAt)}</p>
							<p class="mt-0.5 font-mono text-[10px] text-teal">CRYPTO_VERIFIED</p>
						</div>
						<div class="border border-border p-4">
							<p class="font-mono text-[10px] tracking-widest text-muted">MATURITY DATE</p>
							<p class="mt-1 font-mono text-sm text-ink">{maturityDate(invoice.submittedAt)}</p>
							<p class="mt-0.5 font-mono text-[10px] text-muted">+90 DAYS</p>
						</div>
					</div>

					<div class="mt-4 border border-border p-4">
						<p class="font-mono text-[10px] tracking-widest text-muted">ORIGINATOR</p>
						<p class="mt-1 font-mono text-xs break-all text-ink">{invoice.submitter}</p>
					</div>
				</div>

				<!-- Funding Terms -->
				<div class="border border-border p-6">
					<p class="mb-4 font-mono text-[10px] tracking-widest text-muted">FUNDING TERMS</p>
					<div class="grid grid-cols-2 gap-4">
						<div>
							<label
								for="advance-rate"
								class="mb-1 block font-mono text-[10px] tracking-widest text-muted"
							>
								ADVANCE RATE (BPS)
							</label>
							<input
								id="advance-rate"
								type="number"
								min="1000"
								max="10000"
								step="100"
								bind:value={advanceRateBps}
								disabled={isProcessing || invoice.funded}
								class="w-full border border-border bg-paper px-3 py-2 font-mono text-sm text-ink outline-none focus:border-ink disabled:opacity-50"
							/>
							<p class="mt-1 font-mono text-[10px] text-muted">
								{(advanceRateBps / 100).toFixed(1)}% of invoice amount
							</p>
						</div>
						<div>
							<label
								for="discount-rate"
								class="mb-1 block font-mono text-[10px] tracking-widest text-muted"
							>
								DISCOUNT RATE (BPS)
							</label>
							<input
								id="discount-rate"
								type="number"
								min="10"
								max="5000"
								step="10"
								bind:value={discountRateBps}
								disabled={isProcessing || invoice.funded}
								class="w-full border border-border bg-paper px-3 py-2 font-mono text-sm text-ink outline-none focus:border-ink disabled:opacity-50"
							/>
							<p class="mt-1 font-mono text-[10px] text-muted">
								{(discountRateBps / 100).toFixed(2)}% fee (your yield)
							</p>
						</div>
					</div>

					<!-- Computed summary -->
					<div class="mt-4 grid grid-cols-3 gap-3 border border-dashed border-muted p-4">
						<div>
							<p class="font-mono text-[10px] tracking-widest text-muted">ADVANCE</p>
							<p class="mt-1 font-mono text-base text-ink">{(advanceRateBps / 100).toFixed(1)}%</p>
						</div>
						<div>
							<p class="font-mono text-[10px] tracking-widest text-muted">DISCOUNT</p>
							<p class="mt-1 font-mono text-base text-ink">{(discountRateBps / 100).toFixed(2)}%</p>
						</div>
						<div>
							<p class="font-mono text-[10px] tracking-widest text-muted">TENOR</p>
							<p class="mt-1 font-mono text-base text-ink">90 DAYS</p>
						</div>
					</div>

					<p class="mt-4 text-sm text-muted">
						You will advance <strong class="text-ink">{(advanceRateBps / 100).toFixed(1)}%</strong>
						of the encrypted invoice amount to the SME, earning a
						<strong class="text-ink">{(discountRateBps / 100).toFixed(2)}%</strong> discount fee. The
						invoice token is locked in escrow until repayment.
					</p>
				</div>
			</div>

			<!-- Right sidebar -->
			<div class="space-y-6">
				<!-- FHE Credit Score -->
				<div class="border border-border p-6">
					<p class="mb-4 font-mono text-[10px] tracking-widest text-muted">FHE CREDIT SCORE</p>
					{#if invoice.scoreReady && invoice.score !== null}
						<div class="mb-3 flex items-baseline gap-3">
							<span class="font-display text-5xl {scoreColor(invoice.score)}">
								{scoreGrade(invoice.score)}
							</span>
							<span class="font-mono text-xs tracking-widest {scoreColor(invoice.score)}">
								{scoreTier(invoice.score)}
							</span>
						</div>
						<div class="h-1.5 w-full bg-border">
							<div class="h-full bg-teal transition-all" style="width: {invoice.score}%"></div>
						</div>
						<p class="mt-1 font-mono text-[10px] text-muted">{invoice.score}/100 ENCRYPTED SCORE</p>
					{:else}
						<p class="font-mono text-xs text-muted">SCORE PENDING</p>
						<p class="mt-1 font-mono text-[10px] text-muted">Not yet computed by oracle</p>
					{/if}
				</div>

				<!-- System Readiness -->
				<div class="border border-border p-6">
					<p class="mb-4 font-mono text-[10px] tracking-widest text-muted">SYSTEM READINESS</p>
					<div class="space-y-3">
						<div class="flex items-center justify-between">
							<span class="font-mono text-xs text-ink">PRIVARA</span>
							<span class="font-mono text-[10px] tracking-widest text-teal">READY</span>
						</div>
						<div class="flex items-center justify-between">
							<span class="font-mono text-xs text-ink">LIQUIDITY</span>
							<span class="font-mono text-[10px] tracking-widest text-teal">AVAILABLE</span>
						</div>
						<div class="flex items-center justify-between">
							<span class="font-mono text-xs text-ink">KYC/AML</span>
							<span class="font-mono text-[10px] tracking-widest text-teal">CLEARED</span>
						</div>
						<div class="flex items-center justify-between">
							<span class="font-mono text-xs text-ink">FHE COPROCESSOR</span>
							<span class="font-mono text-[10px] tracking-widest text-teal">ONLINE</span>
						</div>
					</div>

					<div class="mt-4 border border-dashed border-teal/30 p-3">
						<p class="font-mono text-[10px] tracking-widest text-teal">FHE INDICATOR</p>
					</div>
				</div>

				<!-- Wallet -->
				<div class="border border-border p-6">
					<p class="mb-2 font-mono text-[10px] tracking-widest text-muted">CONNECTED WALLET</p>
					{#if wallet.address}
						<p class="font-mono text-[10px] break-all text-ink">{wallet.address}</p>
					{:else}
						<p class="font-mono text-[10px] text-accent">NOT CONNECTED</p>
					{/if}
				</div>

				<!-- CTA -->
				{#if invoice.funded}
					<div class="border border-muted p-4">
						<p class="font-mono text-xs tracking-widest text-muted">POSITION ALREADY FUNDED</p>
					</div>
				{:else if funded}
					<div class="border border-teal p-4">
						<p class="font-mono text-xs tracking-widest text-teal">POSITION FUNDED ✓</p>
						{#if txHash}
							<a
								href={`${EXPLORER}${txHash}`}
								target="_blank"
								rel="noopener noreferrer"
								class="mt-2 inline-block font-mono text-[10px] text-muted transition-colors hover:text-teal"
							>
								VIEW ON EXPLORER ↗
							</a>
						{/if}
						<div class="mt-3">
							<a
								href={resolve('/lender')}
								class="inline-block border border-ink px-4 py-2 font-mono text-[10px] tracking-widest text-ink hover:bg-ink hover:text-paper"
							>
								BACK TO MARKETPLACE →
							</a>
						</div>
					</div>
				{:else}
					{#if error}
						<div class="border border-accent p-4">
							<p class="font-mono text-[10px] text-accent">{error}</p>
						</div>
					{/if}

					{#if step}
						<div class="flex items-center gap-2 border border-dashed border-muted p-4">
							<div
								class="h-3 w-3 shrink-0 animate-spin rounded-full border border-ink border-t-transparent"
							></div>
							<p class="font-mono text-[10px] text-muted">{step}</p>
						</div>
					{/if}

					<button
						onclick={fundPosition}
						disabled={isProcessing || !wallet.address}
						class="w-full border border-ink bg-ink py-4 font-mono text-xs tracking-widest text-paper hover:bg-ink/90 disabled:cursor-not-allowed disabled:opacity-50"
					>
						{isProcessing ? 'PROCESSING…' : 'FUND POSITION →'}
					</button>
				{/if}
			</div>
		</div>
	{/if}
</div>
