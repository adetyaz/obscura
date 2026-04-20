<script lang="ts">
	import { wallet } from '$lib/stores/wallet.svelte';
	import { lenderStore } from '$lib/stores/lender.svelte';
	import { PositionStatus, PoolTier } from '$lib/stores/sme.svelte';
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';

	let filterTier = $state<'all' | 'A' | 'B' | 'C'>('all');
	let filterTenor = $state<'all' | '30D' | '60D' | '90D'>('all');
	let escalating = $state<bigint | null>(null);
	let escalationError = $state<string>('');
	let gracePending = $state<bigint | null>(null);

	const EXPLORER = 'https://sepolia.basescan.org/tx/';

	$effect(() => {
		if (wallet.isRestored && !wallet.isConnected) {
			void goto(resolve('/'));
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

	function scoreGrade(score: number): 'A' | 'B' | 'C' {
		if (score >= 75) return 'A';
		if (score >= 50) return 'B';
		return 'C';
	}

	function gradeClass(score: number): string {
		if (score >= 75) return 'text-teal border-teal';
		if (score >= 50) return 'text-ink border-ink/30';
		return 'text-accent border-accent';
	}

	function riskLabel(score: number): string {
		if (score >= 75) return 'LOW RISK';
		if (score >= 50) return 'MEDIUM';
		return 'HIGH RISK';
	}

	function formatDate(timestamp: bigint): string {
		return new Date(Number(timestamp) * 1000).toLocaleDateString('en-US', {
			month: 'short',
			day: 'numeric',
			year: '2-digit'
		});
	}

	function truncateAddress(addr: string): string {
		return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
	}

	// Wave 2: grace period helpers
	function daysRemaining(ts: bigint): number {
		const now = Math.floor(Date.now() / 1000);
		return Math.max(0, Math.ceil((Number(ts) - now) / 86400));
	}

	function isOverdue(maturityDate: bigint): boolean {
		return Math.floor(Date.now() / 1000) > Number(maturityDate);
	}

	function isPastGrace(gracePeriodEnd: bigint): boolean {
		return Math.floor(Date.now() / 1000) > Number(gracePeriodEnd);
	}

	function poolTierLabel(tier: number): string {
		if (tier === PoolTier.GOVERNMENT) return 'GOV';
		if (tier === PoolTier.RETAIL) return 'RETAIL';
		return 'CORP';
	}

	async function handleEnterGracePeriod(tokenId: bigint) {
		gracePending = tokenId;
		try {
			await lenderStore.enterGracePeriod(tokenId);
			if (wallet.address) lenderStore.loadPositions(wallet.address);
		} catch {
			// silently fail, position status may already be correct
		} finally {
			gracePending = null;
		}
	}

	async function handleTriggerEscalation(tokenId: bigint) {
		escalating = tokenId;
		escalationError = '';
		try {
			await lenderStore.triggerEscalation(tokenId);
			if (wallet.address) lenderStore.loadPositions(wallet.address);
		} catch (e) {
			escalationError = e instanceof Error ? e.message : 'Escalation failed';
		} finally {
			escalating = null;
		}
	}

	let scoredListings = $derived(
		lenderStore.listings.filter((inv) => inv.scoreReady && inv.score !== null && !inv.funded)
	);

	let filteredListings = $derived(
		filterTier === 'all'
			? scoredListings
			: scoredListings.filter((inv) => scoreGrade(inv.score!) === filterTier)
	);

	// Portfolio stats
	const totalPositions = $derived(lenderStore.positions.length);
	const activePositions = $derived(
		lenderStore.positions.filter(
			(p) => p.positionStatus === PositionStatus.ACTIVE || p.positionStatus === PositionStatus.GRACE
		).length
	);
</script>

<div class="mx-auto max-w-6xl px-6 py-10">
	{#if !wallet.isConnected}
		<!-- redirect handled by effect -->
	{:else}
		<!-- Header -->
		<div class="mb-8 flex items-start justify-between">
			<div>
				<p class="mb-1 font-mono text-[10px] tracking-widest text-muted">LENDER MARKETPLACE</p>
				<h1 class="font-display text-3xl text-ink">Invoice Marketplace</h1>
				<p class="mt-2 font-mono text-xs text-muted">
					Scored, verified receivables available for financing
				</p>
			</div>
			<div class="text-right">
				<p class="mb-1 font-mono text-[9px] text-muted">AMOUNTS</p>
				<p class="font-mono text-[10px] text-teal">FHE ENCRYPTED · VISIBLE POST-FUND</p>
			</div>
		</div>

		<div class="grid grid-cols-1 gap-8 lg:grid-cols-3">
			<!-- Left: Marketplace (2/3) -->
			<div class="lg:col-span-2">
				<!-- Filter bar -->
				<div class="mb-4 flex flex-wrap items-center gap-2">
					<span class="mr-1 font-mono text-[9px] tracking-widest text-muted">TIER</span>
					{#each ['all', 'A', 'B', 'C'] as tier (tier)}
						<button
							onclick={() => (filterTier = tier as typeof filterTier)}
							class="px-3 py-1.5 font-mono text-[9px] tracking-wide transition-colors {filterTier ===
							tier
								? 'border border-ink bg-ink text-paper'
								: 'border border-border text-muted hover:border-ink/40 hover:text-ink'}"
						>
							{tier === 'all' ? 'ALL' : tier}
						</button>
					{/each}
					<span class="mx-2 text-border">|</span>
					<span class="mr-1 font-mono text-[9px] tracking-widest text-muted">TENOR</span>
					{#each ['all', '30D', '60D', '90D'] as tenor (tenor)}
						<button
							onclick={() => (filterTenor = tenor as typeof filterTenor)}
							class="px-3 py-1.5 font-mono text-[9px] tracking-wide transition-colors {filterTenor ===
							tenor
								? 'border border-ink bg-ink text-paper'
								: 'border border-border text-muted hover:border-ink/40 hover:text-ink'}"
						>
							{tenor === 'all' ? 'ALL' : tenor}
						</button>
					{/each}
					<span class="ml-auto font-mono text-[9px] text-muted">
						{filteredListings.length} available
					</span>
				</div>

				<!-- Invoice cards -->
				{#if lenderStore.isLoading}
					<div class="flex items-center justify-center gap-2 border border-border py-16">
						<div
							class="h-3 w-3 animate-spin rounded-full border border-ink border-t-transparent"
						></div>
						<p class="font-mono text-[10px] text-muted">Loading marketplace…</p>
					</div>
				{:else if filteredListings.length === 0}
					<div class="border border-dashed border-border p-12 text-center">
						<p class="mb-2 font-mono text-[10px] tracking-widest text-muted">
							NO INVOICES AVAILABLE
						</p>
						<p class="font-mono text-xs text-muted">
							{filterTier === 'all'
								? 'No scored invoices are listed for financing yet.'
								: `No Tier-${filterTier} invoices available.`}
						</p>
					</div>
				{:else}
					<div class="space-y-3">
						{#each filteredListings as invoice (invoice.tokenId)}
							{@const grade = scoreGrade(invoice.score!)}
							<div class="border border-border p-5 transition-colors hover:border-ink/30">
								<div class="flex items-start justify-between gap-4">
									<div class="flex flex-wrap items-center gap-5">
										<!-- Token ID bracket style -->
										<div>
											<p class="mb-0.5 font-mono text-[9px] text-muted">TOKEN</p>
											<p class="font-mono text-xs text-ink">
												[{invoice.tokenId.toString().padStart(4, '0')}]
											</p>
										</div>
										<!-- Tier badge -->
										<div>
											<p class="mb-0.5 font-mono text-[9px] text-muted">TIER</p>
											<span
												class="inline-block border px-1.5 py-0.5 font-mono text-[9px] {gradeClass(
													invoice.score!
												)}"
											>
												TIER-{grade}
											</span>
										</div>
										<!-- Score -->
										<div>
											<p class="mb-0.5 font-mono text-[9px] text-muted">CREDIT SCORE</p>
											<p class="font-mono text-xs {gradeClass(invoice.score!).split(' ')[0]}">
												{invoice.score}/100 · {riskLabel(invoice.score!)}
											</p>
										</div>
										<!-- SME -->
										<div>
											<p class="mb-0.5 font-mono text-[9px] text-muted">ORIGINATOR</p>
											<p class="font-mono text-[10px] text-muted">
												{truncateAddress(invoice.submitter)}
											</p>
										</div>
										<!-- Date -->
										<div>
											<p class="mb-0.5 font-mono text-[9px] text-muted">SUBMITTED</p>
											<p class="font-mono text-[10px] text-muted">
												{formatDate(invoice.submittedAt)}
											</p>
										</div>
										<!-- Amount -->
										<div>
											<p class="mb-0.5 font-mono text-[9px] text-muted">AMOUNT</p>
											<p class="font-mono text-[10px] text-muted">●●●● USDC</p>
										</div>
									</div>
									<!-- Fund button -->
									<a
										href={resolve(`/lender/fund/${invoice.tokenId.toString()}`)}
										class="shrink-0 border border-ink px-4 py-2 font-mono text-[9px] tracking-widest text-ink transition-colors hover:bg-ink hover:text-paper"
									>
										FUND POSITION →
									</a>
								</div>
							</div>
						{/each}
					</div>
				{/if}
			</div>

			<!-- Right: Portfolio sidebar (1/3) -->
			<div class="space-y-5">
				<!-- Portfolio summary -->
				<div class="border border-border p-5">
					<p class="mb-4 font-mono text-[10px] tracking-widest text-muted">PORTFOLIO SUMMARY</p>
					<div class="space-y-4">
						<div class="border-b border-border pb-3">
							<p class="mb-1 font-mono text-[9px] text-muted">TOTAL POSITIONS</p>
							<p class="font-display text-2xl text-ink">{totalPositions}</p>
						</div>
						<div class="border-b border-border pb-3">
							<p class="mb-1 font-mono text-[9px] text-muted">ACTIVE POSITIONS</p>
							<p class="font-display text-2xl text-ink">{activePositions}</p>
						</div>
						<div>
							<p class="mb-1 font-mono text-[9px] text-muted">YIELD MODE</p>
							<p class="font-mono text-xs text-teal">DISCOUNT RATE · AUTO</p>
						</div>
					</div>
				</div>

				<!-- Recent settlements / positions -->
				{#if lenderStore.positions.length > 0}
					<div class="border border-border p-5">
						<p class="mb-3 font-mono text-[10px] tracking-widest text-muted">RECENT POSITIONS</p>
						<div class="space-y-4">
							{#each lenderStore.positions.slice(0, 5) as pos (pos.tokenId)}
								<div class="border-b border-border/60 pb-3 last:border-0 last:pb-0">
									<div class="flex items-center justify-between">
										<div>
											<p class="font-mono text-[10px] text-ink">
												[{pos.tokenId.toString().padStart(4, '0')}] · {poolTierLabel(pos.poolTier)}
											</p>
											<p class="font-mono text-[9px] text-muted">
												{(pos.advanceRateBps / 100).toFixed(1)}% adv · {(
													pos.discountRateBps / 100
												).toFixed(2)}% fee
											</p>
										</div>
										{#if pos.positionStatus === PositionStatus.REPAID || pos.settled}
											<span class="font-mono text-[9px] text-muted">SETTLED</span>
										{:else if pos.positionStatus === PositionStatus.ESCALATED}
											<span class="font-mono text-[9px] text-accent">ESCALATED</span>
										{:else if pos.positionStatus === PositionStatus.GRACE}
											<span class="font-mono text-[9px] text-accent"
												>GRACE {daysRemaining(pos.gracePeriodEnd)}d</span
											>
										{:else}
											<span class="font-mono text-[9px] text-teal">ACTIVE</span>
										{/if}
									</div>

									<!-- Wave 2: grace/escalation actions -->
									{#if pos.positionStatus === PositionStatus.ACTIVE && isOverdue(pos.maturityDate)}
										<button
											onclick={() => handleEnterGracePeriod(pos.tokenId)}
											disabled={gracePending === pos.tokenId}
											class="mt-1.5 w-full border border-accent px-2 py-1 font-mono text-[9px] tracking-wide text-accent transition-colors hover:bg-accent hover:text-paper disabled:opacity-40"
										>
											{gracePending === pos.tokenId ? 'PENDING…' : 'ENTER GRACE PERIOD'}
										</button>
									{:else if pos.positionStatus === PositionStatus.GRACE && isPastGrace(pos.gracePeriodEnd)}
										<button
											onclick={() => handleTriggerEscalation(pos.tokenId)}
											disabled={escalating === pos.tokenId}
											class="mt-1.5 w-full bg-accent px-2 py-1 font-mono text-[9px] tracking-wide text-paper transition-opacity hover:opacity-80 disabled:opacity-40"
										>
											{escalating === pos.tokenId ? 'ESCALATING…' : 'TRIGGER ESCALATION'}
										</button>
									{/if}

									<!-- Maturity date display -->
									{#if pos.positionStatus === PositionStatus.ACTIVE && !isOverdue(pos.maturityDate)}
										<p class="mt-0.5 font-mono text-[9px] text-muted">
											Due {formatDate(pos.maturityDate)} · {daysRemaining(pos.maturityDate)}d
										</p>
									{/if}

									<!-- Escalated: show status -->
									{#if pos.positionStatus === PositionStatus.ESCALATED}
										<p class="mt-1 font-mono text-[9px] text-accent">Escalated to legal process</p>
									{/if}
									{#if escalationError && escalating === null}
										<p class="mt-0.5 font-mono text-[9px] text-accent">{escalationError}</p>
									{/if}
								</div>
							{/each}
						</div>
					</div>
				{/if}

				<!-- FHE indicator -->
				<div class="border border-border p-4">
					<p class="mb-2 font-mono text-[9px] tracking-widest text-muted">PRIVACY LAYER</p>
					<p class="mb-1 font-mono text-[10px] text-teal">● FHE COPROCESSOR ACTIVE</p>
					<p class="font-mono text-[9px] text-muted">
						Invoice amounts remain encrypted until position is funded. Credit scores computed via
						ZKP.
					</p>
				</div>
			</div>
		</div>
	{/if}
</div>
