<script lang="ts">
	import { wallet } from '$lib/stores/wallet.svelte';
	import { lenderStore, type MarketplaceInvoice } from '$lib/stores/lender.svelte';
	import FundConfirmModal from '$lib/components/FundConfirmModal.svelte';
	import { goto } from '$app/navigation';

	let filterTier = $state<'all' | 'high' | 'medium' | 'low'>('all');
	let showFundModal = $state(false);
	let selectedInvoice = $state<MarketplaceInvoice | null>(null);

	$effect(() => {
		if (!wallet.isConnected) {
			void goto('/');
		}
	});

	$effect(() => {
		if (wallet.isConnected && wallet.role === 'lender') {
			lenderStore.loadListings();
			if (wallet.address) {
				lenderStore.loadPositions(wallet.address);
			}
		}
	});

	function openFundModal(invoice: MarketplaceInvoice) {
		selectedInvoice = invoice;
		showFundModal = true;
	}

	function onFunded() {
		lenderStore.loadListings();
		if (wallet.address) {
			lenderStore.loadPositions(wallet.address);
		}
	}

	function scoreTier(score: number): 'high' | 'medium' | 'low' {
		if (score >= 75) return 'high';
		if (score >= 40) return 'medium';
		return 'low';
	}

	function scoreColor(score: number): string {
		if (score >= 75) return 'text-teal';
		if (score >= 40) return 'text-ink';
		return 'text-accent';
	}

	function tierLabel(tier: string): string {
		if (tier === 'high') return 'LOW RISK';
		if (tier === 'medium') return 'MEDIUM';
		return 'HIGH RISK';
	}

	function tierColor(tier: string): string {
		if (tier === 'high') return 'bg-teal/10 text-teal';
		if (tier === 'medium') return 'bg-ink/5 text-ink';
		return 'bg-accent/10 text-accent';
	}

	function formatDate(timestamp: bigint): string {
		return new Date(Number(timestamp) * 1000).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric'
		});
	}

	function truncateAddress(addr: string): string {
		return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
	}

	let scoredListings = $derived(
		lenderStore.listings.filter((inv) => inv.scoreReady && inv.score !== null && !inv.funded)
	);

	let filteredListings = $derived(
		filterTier === 'all'
			? scoredListings
			: scoredListings.filter((inv) => scoreTier(inv.score!) === filterTier)
	);
</script>

<div class="mx-auto max-w-6xl px-6">
	{#if !wallet.isConnected}
		<!-- Redirect handled by $effect -->
	{:else}
		<!-- Header -->
		<section class="border-b border-border py-12">
			<div class="flex items-center justify-between">
				<div>
					<p class="mb-2 font-mono text-xs tracking-widest text-muted">LENDER DASHBOARD</p>
					<h1 class="font-display text-3xl text-ink">Invoice Marketplace</h1>
				</div>
				<p class="font-mono text-[10px] text-muted">
					Showing scored invoices only · amounts encrypted
				</p>
			</div>
		</section>

		<!-- Filters -->
		<section class="flex items-center gap-3 py-6">
			<span class="font-mono text-[10px] tracking-widest text-muted">FILTER:</span>
			{#each ['all', 'high', 'medium', 'low'] as tier (tier)}
				<button
					onclick={() => (filterTier = tier as typeof filterTier)}
					class="px-3 py-1.5 font-mono text-[10px] tracking-wide transition-colors {filterTier ===
					tier
						? 'border border-ink bg-ink text-paper'
						: 'border border-border text-muted hover:text-ink'}"
				>
					{tier === 'all' ? 'ALL' : tierLabel(tier)}
				</button>
			{/each}
			<span class="ml-auto font-mono text-[10px] text-muted">
				{filteredListings.length} invoice{filteredListings.length !== 1 ? 's' : ''}
			</span>
		</section>

		<!-- Listings -->
		<section class="pb-16">
			{#if lenderStore.isLoading}
				<div class="flex items-center gap-2 py-12">
					<div
						class="h-3 w-3 animate-spin border border-ink border-t-transparent"
						style="border-radius: 50%;"
					></div>
					<p class="font-mono text-[10px] text-muted">Loading marketplace…</p>
				</div>
			{:else if filteredListings.length === 0}
				<div class="border border-dashed border-border p-12 text-center">
					<p class="mb-2 font-mono text-xs tracking-widest text-muted">NO SCORED INVOICES</p>
					<p class="text-sm text-muted">
						{filterTier === 'all'
							? 'No invoices with finalized risk scores are available yet.'
							: 'No invoices match the selected risk tier.'}
					</p>
				</div>
			{:else}
				<div class="space-y-3">
					{#each filteredListings as invoice (invoice.tokenId)}
						{@const tier = scoreTier(invoice.score!)}
						<div class="border border-border px-6 py-5">
							<div class="flex items-center justify-between">
								<div class="flex items-center gap-8">
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
										<p class="font-mono text-[10px] tracking-widest text-muted">AMOUNT</p>
										<p class="font-mono text-sm text-muted">●●●● encrypted</p>
									</div>
									<div>
										<p class="font-mono text-[10px] tracking-widest text-muted">SUBMITTER</p>
										<p class="font-mono text-sm text-muted">
											{truncateAddress(invoice.submitter)}
										</p>
									</div>
									<div>
										<p class="font-mono text-[10px] tracking-widest text-muted">SUBMITTED</p>
										<p class="font-mono text-sm text-muted">
											{formatDate(invoice.submittedAt)}
										</p>
									</div>
								</div>
								<div class="flex items-center gap-3">
									<span
										class="rounded-full px-3 py-1 font-mono text-[10px] font-medium tracking-wide {tierColor(
											tier
										)}"
									>
										{tierLabel(tier)}
									</span>
									<button
										onclick={() => openFundModal(invoice)}
										disabled={lenderStore.isFunding}
										class="border border-ink px-5 py-2.5 font-mono text-[10px] tracking-wide text-ink hover:bg-ink hover:text-paper disabled:opacity-50"
									>
										FUND
									</button>
								</div>
							</div>
						</div>
					{/each}
				</div>
			{/if}
		</section>

		<!-- Active Positions -->
		{#if lenderStore.positions.length > 0}
			<section class="border-t border-border py-8">
				<p class="mb-4 font-mono text-xs tracking-widest text-muted">YOUR POSITIONS</p>
				<div class="space-y-3">
					{#each lenderStore.positions as pos (pos.tokenId)}
						<div class="border border-border px-6 py-4">
							<div class="flex items-center justify-between">
								<div class="flex items-center gap-8">
									<div>
										<p class="font-mono text-[10px] tracking-widest text-muted">TOKEN</p>
										<p class="font-mono text-sm text-ink">#{pos.tokenId.toString()}</p>
									</div>
									<div>
										<p class="font-mono text-[10px] tracking-widest text-muted">ADVANCE</p>
										<p class="font-mono text-sm text-ink">
											{(pos.advanceRateBps / 100).toFixed(1)}%
										</p>
									</div>
									<div>
										<p class="font-mono text-[10px] tracking-widest text-muted">FEE</p>
										<p class="font-mono text-sm text-ink">
											{(pos.discountRateBps / 100).toFixed(2)}%
										</p>
									</div>
									<div>
										<p class="font-mono text-[10px] tracking-widest text-muted">SCORE</p>
										<p class="font-mono text-sm text-ink">{pos.score ?? '—'}</p>
									</div>
									<div>
										<p class="font-mono text-[10px] tracking-widest text-muted">FUNDED</p>
										<p class="font-mono text-sm text-muted">
											{formatDate(pos.fundedAt)}
										</p>
									</div>
								</div>
								<span
									class="rounded-full px-3 py-1 font-mono text-[10px] font-medium tracking-wide {pos.settled
										? 'bg-muted/10 text-muted'
										: 'bg-teal/10 text-teal'}"
								>
									{pos.settled ? 'SETTLED' : 'ACTIVE'}
								</span>
							</div>
						</div>
					{/each}
				</div>
			</section>
		{/if}
	{/if}
</div>

<FundConfirmModal bind:open={showFundModal} invoice={selectedInvoice} onfunded={onFunded} />
