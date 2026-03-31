<script lang="ts">
	import { wallet } from '$lib/stores/wallet.svelte';
	import { smeStore } from '$lib/stores/sme.svelte';
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { SvelteMap } from 'svelte/reactivity';

	$effect(() => {
		if (wallet.isRestored && !wallet.isConnected) {
			goto(resolve('/'));
		}
	});

	$effect(() => {
		if (wallet.isConnected && wallet.isVerified && wallet.address) {
			smeStore.loadInvoices(wallet.address);
		}
	});

	let scoringId = $state<bigint | null>(null);
	let scoringError = $state('');
	let scoringErrorId = $state<bigint | null>(null);
	let txHashes = new SvelteMap<bigint, `0x${string}`>();

	const EXPLORER = 'https://sepolia.basescan.org/tx/';

	async function handleRequestScore(tokenId: bigint) {
		scoringId = tokenId;
		scoringError = '';
		scoringErrorId = null;
		try {
			const hash = await smeStore.requestScore(tokenId);
			txHashes.set(tokenId, hash);
			if (wallet.address) await smeStore.loadInvoices(wallet.address);
		} catch (e: unknown) {
			scoringError = e instanceof Error ? e.message : 'Transaction failed';
			scoringErrorId = tokenId;
		} finally {
			scoringId = null;
		}
	}

	async function handleFinalizeScore(tokenId: bigint) {
		scoringId = tokenId;
		scoringError = '';
		scoringErrorId = null;
		try {
			const hash = await smeStore.finalizeScore(tokenId);
			txHashes.set(tokenId, hash);
			if (wallet.address) await smeStore.loadInvoices(wallet.address);
		} catch (e: unknown) {
			scoringError = e instanceof Error ? e.message : 'Transaction failed';
			scoringErrorId = tokenId;
		} finally {
			scoringId = null;
		}
	}

	function formatDate(timestamp: bigint): string {
		return new Date(Number(timestamp) * 1000).toLocaleDateString('en-US', {
			month: 'short',
			day: 'numeric',
			year: '2-digit'
		});
	}

	function scoreGrade(score: number | null): string {
		if (score === null) return '—';
		if (score >= 75) return 'A';
		if (score >= 50) return 'B';
		return 'C';
	}

	function gradeClass(score: number | null): string {
		if (score === null) return 'text-muted';
		if (score >= 75) return 'text-teal';
		if (score >= 50) return 'text-ink';
		return 'text-accent';
	}

	function tierLabel(invoice: (typeof smeStore.invoices)[0]): string {
		if (!invoice.scoreReady || invoice.score === null) return '—';
		if (invoice.score >= 75) return 'TIER-A';
		if (invoice.score >= 50) return 'TIER-B';
		return 'TIER-C';
	}

	function statusLabel(invoice: (typeof smeStore.invoices)[0]): { text: string; classes: string } {
		if (invoice.settled) return { text: 'SETTLED', classes: 'text-muted bg-muted/10' };
		if (invoice.funded) return { text: 'FUNDED', classes: 'text-teal bg-teal/10' };
		if (invoice.scoreReady) return { text: 'SCORED', classes: 'text-ink bg-ink/5' };
		if (invoice.scoreRequested) return { text: 'SCORING', classes: 'text-accent bg-accent/10' };
		if (invoice.active) return { text: 'ACTIVE', classes: 'text-teal bg-teal/10' };
		return { text: 'INACTIVE', classes: 'text-muted bg-muted/10' };
	}

	const totalReceivables = $derived(smeStore.invoices.filter((i) => i.active && !i.settled).length);
	const activeAdvances = $derived(smeStore.invoices.filter((i) => i.funded && !i.settled).length);
	const avgScore = $derived(() => {
		const scored = smeStore.invoices.filter((i) => i.scoreReady && i.score !== null);
		if (scored.length === 0) return null;
		return Math.round(scored.reduce((s, i) => s + (i.score ?? 0), 0) / scored.length);
	});
</script>

<div class="mx-auto max-w-6xl px-6 py-10">
	{#if !wallet.isConnected}
		<!-- handled by $effect -->
	{:else if !wallet.isVerified}
		<!-- KYB prompt -->
		<div class="py-24 text-center">
			<p class="mb-3 font-mono text-[10px] tracking-widest text-muted">VERIFICATION REQUIRED</p>
			<h1 class="mb-4 font-display text-3xl text-ink">Complete KYB Onboarding</h1>
			<p class="mx-auto mb-8 max-w-md font-mono text-xs text-muted">
				Your business must be verified before submitting invoices for financing.
			</p>
			<a
				href={resolve('/sme/kyb')}
				class="inline-block bg-ink px-6 py-3 font-mono text-xs tracking-widest text-paper transition-opacity hover:opacity-80"
			>
				START KYB VERIFICATION
			</a>
		</div>
	{:else}
		<!-- Header row -->
		<div class="mb-8 flex items-start justify-between">
			<div>
				<p class="mb-1 font-mono text-[10px] tracking-widest text-muted">SME ORIGINATOR PORTAL</p>
				<h1 class="font-display text-3xl text-ink">Dashboard</h1>
				<div class="mt-2 flex items-center gap-2">
					<span class="font-mono text-xs text-muted">{wallet.address?.slice(0, 10)}…</span>
					<span
						class="rounded-full bg-teal/10 px-2 py-0.5 font-mono text-[10px] tracking-wide text-teal"
					>
						VERIFIED ✓
					</span>
				</div>
			</div>
			<a
				href={resolve('/sme/invoice')}
				class="bg-ink px-5 py-2.5 font-mono text-xs tracking-widest text-paper transition-opacity hover:opacity-80"
			>
				+ SUBMIT INVOICE
			</a>
		</div>

		<!-- Stats row -->
		<div class="mb-8 grid grid-cols-3 gap-px border border-border bg-border">
			<div class="bg-paper px-6 py-5">
				<p class="mb-1 font-mono text-[10px] tracking-widest text-muted">TOTAL RECEIVABLES</p>
				<p class="font-display text-2xl text-ink">{totalReceivables}</p>
				<p class="mt-0.5 font-mono text-[10px] text-muted">Active invoices</p>
			</div>
			<div class="bg-paper px-6 py-5">
				<p class="mb-1 font-mono text-[10px] tracking-widest text-muted">ACTIVE ADVANCES</p>
				<p class="font-display text-2xl text-ink">{activeAdvances}</p>
				<p class="mt-0.5 font-mono text-[10px] text-muted">Funded positions</p>
			</div>
			<div class="bg-paper px-6 py-5">
				<p class="mb-1 font-mono text-[10px] tracking-widest text-muted">PROTOCOL REPUTATION</p>
				<p class="font-display text-2xl text-ink">
					{avgScore() !== null ? `${avgScore()}/100` : '—'}
				</p>
				<p class="mt-0.5 font-mono text-[10px] text-muted">Avg credit score</p>
			</div>
		</div>

		<!-- Invoice table -->
		<div class="mb-8">
			<div class="mb-3 flex items-center justify-between">
				<p class="font-mono text-[10px] tracking-widest text-muted">INVOICE REGISTRY</p>
				{#if smeStore.isLoading}
					<span class="font-mono text-[10px] text-muted">Loading…</span>
				{/if}
			</div>

			{#if smeStore.isLoading}
				<div class="flex items-center justify-center gap-2 border border-border py-12">
					<div
						class="h-3 w-3 animate-spin rounded-full border border-ink border-t-transparent"
					></div>
					<p class="font-mono text-[10px] text-muted">Fetching encrypted invoices…</p>
				</div>
			{:else if smeStore.invoices.length === 0}
				<div class="border border-dashed border-border p-12 text-center">
					<p class="mb-2 font-mono text-[10px] tracking-widest text-muted">NO INVOICES FOUND</p>
					<p class="font-mono text-xs text-muted">
						Submit your first invoice to begin the financing process.
					</p>
				</div>
			{:else}
				<!-- Table header -->
				<div
					class="grid grid-cols-[80px_90px_70px_100px_1fr] gap-4 border-b border-border px-4 py-2.5"
				>
					<p class="font-mono text-[9px] tracking-widest text-muted">TOKEN ID</p>
					<p class="font-mono text-[9px] tracking-widest text-muted">SUBMITTED</p>
					<p class="font-mono text-[9px] tracking-widest text-muted">TIER</p>
					<p class="font-mono text-[9px] tracking-widest text-muted">STATUS</p>
					<p class="font-mono text-[9px] tracking-widest text-muted">ACTIONS</p>
				</div>

				{#each smeStore.invoices as invoice (invoice.tokenId)}
					{@const status = statusLabel(invoice)}
					<div
						class="grid grid-cols-[80px_90px_70px_100px_1fr] items-center gap-4 border-b border-border px-4 py-3.5 transition-colors hover:bg-ink/1.5"
					>
						<!-- Token ID -->
						<p class="font-mono text-xs text-ink">
							[{invoice.tokenId.toString().padStart(4, '0')}]
						</p>

						<!-- Date -->
						<p class="font-mono text-xs text-muted">{formatDate(invoice.submittedAt)}</p>

						<!-- Tier + Grade -->
						<div>
							<p class="font-mono text-[10px] text-ink">{tierLabel(invoice)}</p>
							{#if invoice.scoreReady && invoice.score !== null}
								<p class="font-mono text-[9px] {gradeClass(invoice.score)}">
									{scoreGrade(invoice.score)} · {invoice.score}/100
								</p>
							{/if}
						</div>

						<!-- Status badge -->
						<span
							class="inline-block rounded-full px-2 py-0.5 font-mono text-[9px] tracking-wide {status.classes}"
						>
							{status.text}
						</span>

						<!-- Actions -->
						<div class="flex flex-wrap items-center gap-2">
							{#if !invoice.funded && !invoice.scoreRequested}
								<button
									onclick={() => handleRequestScore(invoice.tokenId)}
									disabled={scoringId !== null}
									class="border border-ink px-3 py-1.5 font-mono text-[9px] tracking-wide text-ink transition-colors hover:bg-ink hover:text-paper disabled:opacity-40"
								>
									{scoringId === invoice.tokenId ? 'SCORING…' : 'REQUEST SCORE'}
								</button>
							{:else if !invoice.funded && invoice.scoreRequested && !invoice.scoreReady}
								<button
									onclick={() => handleFinalizeScore(invoice.tokenId)}
									disabled={scoringId !== null}
									class="border border-teal px-3 py-1.5 font-mono text-[9px] tracking-wide text-teal transition-colors hover:bg-teal hover:text-paper disabled:opacity-40"
								>
									{scoringId === invoice.tokenId ? 'FINALIZING…' : 'FINALIZE SCORE'}
								</button>
							{/if}

							{#if scoringError && scoringErrorId === invoice.tokenId}
								<p class="w-full font-mono text-[9px] text-accent">{scoringError}</p>
							{/if}

							{#if txHashes.has(invoice.tokenId)}
								<a
									href={`${EXPLORER}${txHashes.get(invoice.tokenId)}`}
									target="_blank"
									rel="noopener noreferrer"
									class="font-mono text-[9px] text-muted transition-colors hover:text-teal"
								>
									VIEW ON EXPLORER ↗
								</a>
							{/if}

							{#if invoice.funded && !invoice.settled}
								<a
									href={resolve(`/sme/repay/${invoice.tokenId.toString()}`)}
									class="border border-accent px-3 py-1.5 font-mono text-[9px] tracking-wide text-accent transition-colors hover:bg-accent hover:text-paper"
								>
									REPAY →
								</a>
							{/if}

							{#if invoice.scoreReady && !invoice.funded && !invoice.settled}
								<span class="font-mono text-[9px] text-muted">Awaiting lender</span>
							{/if}

							{#if invoice.settled}
								<span class="font-mono text-[9px] text-muted">Settlement complete</span>
							{/if}
						</div>
					</div>
				{/each}
			{/if}
		</div>

		<!-- FHE status panel -->
		<div class="border border-border p-5">
			<div class="mb-3 flex items-center justify-between">
				<p class="font-mono text-[10px] tracking-widest text-muted">FHE ENCRYPTION STATUS</p>
				<span class="font-mono text-[10px] text-teal">● FHENIX COPROCESSOR v1.2.4</span>
			</div>
			<div class="grid grid-cols-3 gap-4">
				<div>
					<p class="mb-1 font-mono text-[9px] text-muted">NETWORK</p>
					<p class="font-mono text-xs text-ink">Base Sepolia</p>
				</div>
				<div>
					<p class="mb-1 font-mono text-[9px] text-muted">CHAIN ID</p>
					<p class="font-mono text-xs text-ink">84532</p>
				</div>
				<div>
					<p class="mb-1 font-mono text-[9px] text-muted">ENCRYPTION</p>
					<p class="font-mono text-xs text-teal">FHE UINT128 · ACTIVE</p>
				</div>
			</div>
		</div>
	{/if}
</div>
