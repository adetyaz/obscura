<script lang="ts">
	import type { MarketplaceInvoice } from '$lib/stores/lender.svelte';
	import { lenderStore } from '$lib/stores/lender.svelte';
	import { disburseAdvance } from '$lib/privara/client';

	let {
		open = $bindable(false),
		invoice,
		onfunded
	}: { open: boolean; invoice: MarketplaceInvoice | null; onfunded?: () => void } = $props();

	let advanceRateBps = $state(8500); // 85%
	let discountRateBps = $state(200); // 2%
	let step = $state('');
	let error = $state('');
	let isProcessing = $state(false);

	function close() {
		if (isProcessing) return;
		open = false;
		step = '';
		error = '';
	}

	function scoreTier(score: number): string {
		if (score >= 75) return 'LOW RISK';
		if (score >= 40) return 'MEDIUM';
		return 'HIGH RISK';
	}

	function scoreColor(score: number): string {
		if (score >= 75) return 'text-teal';
		if (score >= 40) return 'text-ink';
		return 'text-accent';
	}

	async function confirmFund() {
		if (!invoice) return;

		isProcessing = true;
		error = '';

		try {
			// Step 1: Call FinancingPool.fundInvoice on-chain
			step = 'Submitting funding transaction…';
			await lenderStore.fundInvoice(invoice.tokenId, advanceRateBps, discountRateBps, 90);

			// Step 2: Trigger Privara escrow creation on ReineiraOS
			step = 'Triggering USDC disbursement via Privara…';
			await disburseAdvance(invoice.submitter, 0n, invoice.tokenId);

			step = 'Invoice funded successfully!';

			// Brief pause so user sees success
			await new Promise((r) => setTimeout(r, 1000));

			open = false;
			step = '';
			onfunded?.();
		} catch (err) {
			error = err instanceof Error ? err.message : 'Funding failed';
			step = '';
		} finally {
			isProcessing = false;
		}
	}
</script>

{#if open && invoice}
	<!-- svelte-ignore a11y_no_noninteractive_element_interactions -->
	<div
		class="fixed inset-0 z-50 flex items-center justify-center bg-ink/40"
		role="dialog"
		tabindex="-1"
		onkeydown={(e) => e.key === 'Escape' && close()}
	>
		<div class="w-full max-w-lg border border-border bg-paper p-8">
			<!-- Header -->
			<div class="mb-6 flex items-center justify-between">
				<h2 class="font-display text-xl text-ink">Fund Invoice</h2>
				<button
					onclick={close}
					disabled={isProcessing}
					class="font-mono text-xs text-muted hover:text-ink"
				>
					✕
				</button>
			</div>

			<!-- Invoice summary -->
			<div class="mb-6 border border-border p-4">
				<div class="flex items-center gap-6">
					<div>
						<p class="font-mono text-[10px] tracking-widest text-muted">TOKEN</p>
						<p class="font-mono text-sm text-ink">#{invoice.tokenId.toString()}</p>
					</div>
					<div>
						<p class="font-mono text-[10px] tracking-widest text-muted">RISK SCORE</p>
						<p class="font-mono text-lg font-medium {scoreColor(invoice.score!)}">
							{invoice.score}
						</p>
					</div>
					<div>
						<p class="font-mono text-[10px] tracking-widest text-muted">TIER</p>
						<p class="font-mono text-xs">{scoreTier(invoice.score!)}</p>
					</div>
					<div>
						<p class="font-mono text-[10px] tracking-widest text-muted">AMOUNT</p>
						<p class="font-mono text-sm text-muted">●●●● encrypted</p>
					</div>
				</div>
			</div>

			<!-- Terms -->
			<div class="mb-6 space-y-4">
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
						disabled={isProcessing}
						class="w-full border border-border bg-paper px-3 py-2 font-mono text-sm text-ink outline-none focus:border-ink"
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
						disabled={isProcessing}
						class="w-full border border-border bg-paper px-3 py-2 font-mono text-sm text-ink outline-none focus:border-ink"
					/>
					<p class="mt-1 font-mono text-[10px] text-muted">
						{(discountRateBps / 100).toFixed(2)}% fee (your yield)
					</p>
				</div>
			</div>

			<!-- Summary box -->
			<div class="mb-6 border border-dashed border-muted p-4">
				<p class="font-mono text-[10px] tracking-widest text-muted">TERMS SUMMARY</p>
				<p class="mt-2 text-sm text-ink">
					You will advance <strong>{(advanceRateBps / 100).toFixed(1)}%</strong> of the encrypted
					invoice amount to the SME, earning a
					<strong>{(discountRateBps / 100).toFixed(2)}%</strong> discount fee. The invoice token will
					be locked in escrow until the SME repays.
				</p>
			</div>

			{#if step}
				<div class="mb-4 flex items-center gap-2">
					{#if !error}
						<div
							class="h-3 w-3 animate-spin border border-ink border-t-transparent"
							style="border-radius: 50%;"
						></div>
					{/if}
					<p class="font-mono text-[10px] text-muted">{step}</p>
				</div>
			{/if}

			{#if error}
				<p class="mb-4 font-mono text-xs text-accent">{error}</p>
			{/if}

			<!-- Actions -->
			<div class="flex gap-3">
				<button
					onclick={close}
					disabled={isProcessing}
					class="flex-1 border border-border px-4 py-3 font-mono text-[10px] tracking-wide text-muted hover:text-ink"
				>
					CANCEL
				</button>
				<button
					onclick={confirmFund}
					disabled={isProcessing}
					class="flex-1 border border-ink bg-ink px-4 py-3 font-mono text-[10px] tracking-wide text-paper hover:bg-ink/90 disabled:opacity-50"
				>
					{isProcessing ? 'PROCESSING…' : 'CONFIRM FUNDING'}
				</button>
			</div>
		</div>
	</div>
{/if}
