<script lang="ts">
	import { wallet } from '$lib/stores/wallet.svelte';
	import { smeStore } from '$lib/stores/sme.svelte';
	import { goto } from '$app/navigation';
	import KYBModal from '$lib/components/KYBModal.svelte';
	import InvoiceSubmitModal from '$lib/components/InvoiceSubmitModal.svelte';

	let showKYB = $state(false);
	let showSubmit = $state(false);
	let scoringId = $state<bigint | null>(null);
	let settlingId = $state<bigint | null>(null);
	let settleStep = $state('');

	$effect(() => {
		if (!wallet.isConnected) {
			goto('/');
		}
	});

	$effect(() => {
		if (wallet.isConnected && wallet.isVerified && wallet.address) {
			smeStore.loadInvoices(wallet.address);
		}
	});

	function handleSubmitted() {
		if (wallet.address) {
			smeStore.loadInvoices(wallet.address);
		}
	}

	async function handleRequestScore(tokenId: bigint) {
		scoringId = tokenId;
		try {
			await smeStore.requestScore(tokenId);
			if (wallet.address) await smeStore.loadInvoices(wallet.address);
		} finally {
			scoringId = null;
		}
	}

	async function handleFinalizeScore(tokenId: bigint) {
		scoringId = tokenId;
		try {
			await smeStore.finalizeScore(tokenId);
			if (wallet.address) await smeStore.loadInvoices(wallet.address);
		} finally {
			scoringId = null;
		}
	}

	async function handleRequestSettlement(tokenId: bigint) {
		settlingId = tokenId;
		settleStep = 'Requesting settlement…';
		try {
			await smeStore.requestSettlement(tokenId);
			if (wallet.address) await smeStore.loadInvoices(wallet.address);
		} finally {
			settlingId = null;
			settleStep = '';
		}
	}

	async function handleFinalizeSettlement(tokenId: bigint) {
		settlingId = tokenId;
		settleStep = 'Finalizing settlement…';
		try {
			await smeStore.finalizeSettlement(tokenId);
			if (wallet.address) await smeStore.loadInvoices(wallet.address);
		} finally {
			settlingId = null;
			settleStep = '';
		}
	}

	async function handleRepay(tokenId: bigint, amount: bigint) {
		settlingId = tokenId;
		settleStep = 'Sending repayment…';
		try {
			await smeStore.repay(tokenId, amount);
			if (wallet.address) await smeStore.loadInvoices(wallet.address);
		} finally {
			settlingId = null;
			settleStep = '';
		}
	}

	function formatDate(timestamp: bigint): string {
		return new Date(Number(timestamp) * 1000).toLocaleDateString('en-US', {
			year: 'numeric',
			month: 'short',
			day: 'numeric'
		});
	}

	function scoreColor(score: number): string {
		if (score >= 75) return 'text-teal';
		if (score >= 40) return 'text-ink';
		return 'text-accent';
	}

	function statusLabel(invoice: (typeof smeStore.invoices)[0]): { text: string; classes: string } {
		if (invoice.settled) return { text: 'SETTLED', classes: 'bg-muted/10 text-muted' };
		if (invoice.funded) return { text: 'FUNDED', classes: 'bg-teal/10 text-teal' };
		if (invoice.active) return { text: 'ACTIVE', classes: 'bg-teal/10 text-teal' };
		return { text: 'CLOSED', classes: 'bg-muted/10 text-muted' };
	}
</script>

<div class="mx-auto max-w-6xl px-6">
	{#if !wallet.isConnected}
		<!-- Redirect handled by $effect -->
	{:else if !wallet.isVerified}
		<!-- Unverified state — prompt KYB -->
		<section class="py-24">
			<p class="mb-4 font-mono text-xs tracking-widest text-muted">01 — VERIFICATION REQUIRED</p>
			<h1 class="mb-4 max-w-lg font-display text-4xl leading-tight text-ink">
				Complete business verification
			</h1>
			<p class="mb-8 max-w-md text-sm leading-relaxed text-muted">
				Before submitting invoices, your business must be verified through our KYB process. This is
				a one-time step.
			</p>
			<button
				onclick={() => (showKYB = true)}
				class="border border-ink bg-ink px-6 py-3 font-mono text-xs tracking-wide text-paper transition-colors hover:bg-transparent hover:text-ink"
			>
				START VERIFICATION
			</button>
		</section>
	{:else}
		<!-- Verified SME dashboard -->
		<section class="border-b border-border py-12">
			<div class="flex items-center justify-between">
				<div>
					<p class="mb-2 font-mono text-xs tracking-widest text-muted">SME DASHBOARD</p>
					<h1 class="font-display text-3xl text-ink">Your Invoices</h1>
				</div>
				<span
					class="rounded-full bg-teal/10 px-3 py-1 font-mono text-[10px] font-medium tracking-wide text-teal"
				>
					VERIFIED
				</span>
			</div>
		</section>

		<!-- Invoice actions -->
		<section class="py-8">
			<button
				onclick={() => (showSubmit = true)}
				class="border border-ink bg-ink px-6 py-3 font-mono text-xs tracking-wide text-paper transition-colors hover:bg-transparent hover:text-ink"
			>
				SUBMIT NEW INVOICE
			</button>
		</section>

		<!-- Invoice list -->
		<section class="py-8">
			{#if smeStore.isLoading}
				<div class="flex items-center gap-2 py-12">
					<div
						class="h-3 w-3 animate-spin border border-ink border-t-transparent"
						style="border-radius: 50%;"
					></div>
					<p class="font-mono text-[10px] text-muted">Loading invoices…</p>
				</div>
			{:else if smeStore.invoices.length === 0}
				<div class="border border-dashed border-border p-12 text-center">
					<p class="mb-2 font-mono text-xs tracking-widest text-muted">NO INVOICES YET</p>
					<p class="text-sm text-muted">
						Submit your first invoice to get it encrypted, scored, and listed for financing.
					</p>
				</div>
			{:else}
				<div class="space-y-3">
					{#each smeStore.invoices as invoice (invoice.tokenId)}
						{@const status = statusLabel(invoice)}
						<div class="border border-border px-6 py-4">
							<div class="flex items-center justify-between">
								<div class="flex items-center gap-6">
									<div>
										<p class="font-mono text-[10px] tracking-widest text-muted">TOKEN ID</p>
										<p class="font-mono text-sm text-ink">#{invoice.tokenId.toString()}</p>
									</div>
									<div>
										<p class="font-mono text-[10px] tracking-widest text-muted">SUBMITTED</p>
										<p class="font-mono text-sm text-ink">{formatDate(invoice.submittedAt)}</p>
									</div>
									<div>
										<p class="font-mono text-[10px] tracking-widest text-muted">AMOUNT</p>
										<p class="font-mono text-sm text-muted">●●●● encrypted</p>
									</div>
									<div>
										<p class="font-mono text-[10px] tracking-widest text-muted">RISK SCORE</p>
										{#if invoice.scoreReady && invoice.score !== null}
											<p class="font-mono text-sm font-medium {scoreColor(invoice.score)}">
												{invoice.score}/100
											</p>
										{:else if invoice.scoreRequested}
											<p class="font-mono text-sm text-muted">pending…</p>
										{:else}
											<p class="font-mono text-sm text-muted">—</p>
										{/if}
									</div>
									{#if invoice.funded && invoice.advanceRateBps}
										<div>
											<p class="font-mono text-[10px] tracking-widest text-muted">ADVANCE</p>
											<p class="font-mono text-sm text-ink">
												{(invoice.advanceRateBps / 100).toFixed(1)}%
											</p>
										</div>
									{/if}
									{#if invoice.settlementReady && invoice.repayAmount !== null}
										<div>
											<p class="font-mono text-[10px] tracking-widest text-muted">REPAY DUE</p>
											<p class="font-mono text-sm text-accent">
												{invoice.repayAmount.toString()} wei
											</p>
										</div>
									{/if}
								</div>
								<div class="flex items-center gap-3">
									{#if settlingId === invoice.tokenId}
										<span class="font-mono text-[10px] text-muted">{settleStep}</span>
									{/if}

									<!-- Scoring buttons (unfunded only) -->
									{#if !invoice.funded && !invoice.scoreRequested}
										<button
											onclick={() => handleRequestScore(invoice.tokenId)}
											disabled={scoringId !== null}
											class="border border-ink px-4 py-2 font-mono text-[10px] tracking-wide text-ink transition-colors hover:bg-ink hover:text-paper disabled:opacity-50"
										>
											{scoringId === invoice.tokenId ? 'SCORING…' : 'REQUEST SCORE'}
										</button>
									{:else if !invoice.funded && !invoice.scoreReady}
										<button
											onclick={() => handleFinalizeScore(invoice.tokenId)}
											disabled={scoringId !== null}
											class="border border-teal px-4 py-2 font-mono text-[10px] tracking-wide text-teal transition-colors hover:bg-teal hover:text-paper disabled:opacity-50"
										>
											{scoringId === invoice.tokenId ? 'FINALIZING…' : 'FINALIZE SCORE'}
										</button>
									{/if}

									<!-- Repayment buttons (funded, not settled) -->
									{#if invoice.funded && !invoice.settled}
										{#if !invoice.settlementRequested}
											<button
												onclick={() => handleRequestSettlement(invoice.tokenId)}
												disabled={settlingId !== null}
												class="border border-accent px-4 py-2 font-mono text-[10px] tracking-wide text-accent transition-colors hover:bg-accent hover:text-paper disabled:opacity-50"
											>
												INITIATE REPAY
											</button>
										{:else if !invoice.settlementReady}
											<button
												onclick={() => handleFinalizeSettlement(invoice.tokenId)}
												disabled={settlingId !== null}
												class="border border-accent px-4 py-2 font-mono text-[10px] tracking-wide text-accent transition-colors hover:bg-accent hover:text-paper disabled:opacity-50"
											>
												FINALIZE AMOUNT
											</button>
										{:else if invoice.repayAmount !== null}
											<button
												onclick={() => handleRepay(invoice.tokenId, invoice.repayAmount!)}
												disabled={settlingId !== null}
												class="border border-ink bg-ink px-4 py-2 font-mono text-[10px] tracking-wide text-paper transition-colors hover:bg-transparent hover:text-ink disabled:opacity-50"
											>
												PAY & SETTLE
											</button>
										{/if}
									{/if}

									<span
										class="rounded-full px-3 py-1 font-mono text-[10px] font-medium tracking-wide {status.classes}"
									>
										{status.text}
									</span>
								</div>
							</div>
						</div>
					{/each}
				</div>
			{/if}
		</section>
	{/if}
</div>

<KYBModal bind:open={showKYB} />
<InvoiceSubmitModal bind:open={showSubmit} onsubmitted={handleSubmitted} />
