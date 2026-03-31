<script lang="ts">
	import { page } from '$app/stores';
	import { onMount } from 'svelte';
	import { wallet } from '$lib/stores/wallet.svelte';
	import { smeStore } from '$lib/stores/sme.svelte';
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';

	const tokenIdParam = $derived($page.params.tokenId ?? '0');
	const tokenId = $derived(BigInt(tokenIdParam));

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

	onMount(() => {
		if (wallet.address) smeStore.loadInvoices(wallet.address);
	});

	const invoice = $derived(smeStore.invoices.find((i) => i.tokenId === tokenId) ?? null);

	let step = $state('');
	let isWorking = $state(false);
	let error = $state('');
	let done = $state(false);
	let lastTxHash = $state<`0x${string}` | null>(null);

	const EXPLORER = 'https://sepolia.basescan.org/tx/';

	function formatUSDC(wei: bigint): string {
		return (Number(wei) / 1e6).toLocaleString('en-US', {
			style: 'currency',
			currency: 'USD',
			minimumFractionDigits: 2
		});
	}

	function shortAddr(addr: string | null): string {
		if (!addr) return '—';
		return `${addr.slice(0, 10)}…${addr.slice(-8)}`;
	}

	async function handleRequestSettlement() {
		if (!invoice) return;
		isWorking = true;
		step = 'Requesting settlement computation…';
		error = '';
		try {
			const hash = await smeStore.requestSettlement(invoice.tokenId);
			lastTxHash = hash;
			if (wallet.address) await smeStore.loadInvoices(wallet.address);
		} catch (e: unknown) {
			error = e instanceof Error ? e.message : 'Transaction failed';
		} finally {
			isWorking = false;
			step = '';
		}
	}

	async function handleFinalizeSettlement() {
		if (!invoice) return;
		isWorking = true;
		step = 'Finalizing settlement amount…';
		error = '';
		try {
			const hash = await smeStore.finalizeSettlement(invoice.tokenId);
			lastTxHash = hash;
			if (wallet.address) await smeStore.loadInvoices(wallet.address);
		} catch (e: unknown) {
			error = e instanceof Error ? e.message : 'Transaction failed';
		} finally {
			isWorking = false;
			step = '';
		}
	}

	async function handleRepay() {
		if (!invoice || invoice.repayAmount === null) return;
		isWorking = true;
		step = 'Sending repayment…';
		error = '';
		try {
			const hash = await smeStore.repay(invoice.tokenId, invoice.repayAmount);
			lastTxHash = hash;
			if (wallet.address) await smeStore.loadInvoices(wallet.address);
			done = true;
		} catch (e: unknown) {
			error = e instanceof Error ? e.message : 'Transaction failed';
		} finally {
			isWorking = false;
			step = '';
		}
	}

	function settlementStatus(): string {
		if (!invoice) return '';
		if (invoice.settled) return 'SETTLED';
		if (invoice.settlementReady) return 'READY_FOR_SETTLEMENT';
		if (invoice.settlementRequested) return 'COMPUTING';
		if (invoice.funded) return 'FUNDED — AWAITING_REPAY';
		return 'PENDING';
	}
</script>

<div class="min-h-screen bg-paper px-6 py-10">
	<div class="mx-auto max-w-3xl">
		<!-- Breadcrumb -->
		<div class="mb-8 flex items-center gap-2 font-mono text-[10px] tracking-widest text-muted">
			<a href={resolve('/sme')} class="transition-colors hover:text-ink">SME PORTAL</a>
			<span>/</span>
			<span class="text-ink">SETTLEMENT PORTAL</span>
		</div>

		{#if smeStore.isLoading}
			<div class="flex items-center justify-center gap-2 py-24">
				<div class="h-3 w-3 animate-spin rounded-full border border-ink border-t-transparent"></div>
				<p class="font-mono text-[10px] text-muted">Loading invoice data…</p>
			</div>
		{:else if !invoice}
			<div class="border border-border py-24 text-center">
				<p class="mb-3 font-mono text-[10px] tracking-widest text-muted">INVOICE NOT FOUND</p>
				<p class="mb-6 font-mono text-xs text-muted">
					Token #{tokenIdParam} not found in your portfolio.
				</p>
				<a href={resolve('/sme')} class="font-mono text-xs text-ink underline hover:no-underline"
					>← Back to dashboard</a
				>
			</div>
		{:else if done || invoice.settled}
			<!-- Settlement complete -->
			<div class="border border-teal bg-teal/5 px-6 py-10 text-center">
				<p class="mb-2 font-mono text-xs tracking-widest text-teal">SETTLEMENT COMPLETE</p>
				<p class="mb-4 font-display text-2xl text-ink">
					Token #{invoice.tokenId.toString()} Settled
				</p>
				<p class="mb-6 font-mono text-xs text-muted">
					Funds have been routed to the lender. ERC-1155 token burn confirmed.
				</p>
				{#if lastTxHash}
					<a
						href={`${EXPLORER}${lastTxHash}`}
						target="_blank"
						rel="noopener noreferrer"
						class="mb-4 inline-block font-mono text-[10px] text-muted transition-colors hover:text-teal"
					>
						VIEW ON EXPLORER ↗
					</a>
				{/if}
				<a
					href={resolve('/sme')}
					class="inline-block bg-ink px-6 py-3 font-mono text-xs tracking-widest text-paper transition-opacity hover:opacity-80"
				>
					RETURN TO DASHBOARD
				</a>
			</div>
		{:else}
			<!-- Page header -->
			<div class="mb-8 border-b border-border pb-6">
				<div class="flex items-center justify-between">
					<div>
						<p class="mb-1 font-mono text-[10px] tracking-widest text-muted">
							TOKEN #{invoice.tokenId.toString().padStart(4, '0')}
						</p>
						<h1 class="font-display text-3xl text-ink">Settlement Portal</h1>
					</div>
					<div class="text-right">
						<p class="mb-1 font-mono text-[10px] text-muted">STATUS</p>
						<span class="font-mono text-xs text-accent">{settlementStatus()}</span>
					</div>
				</div>
			</div>

			<div class="grid grid-cols-1 gap-6 lg:grid-cols-2">
				<!-- Left: Payment breakdown -->
				<div class="space-y-5">
					<!-- Settlement line items -->
					<div class="border border-border p-5">
						<p class="mb-4 font-mono text-[10px] tracking-widest text-muted">
							SETTLEMENT BREAKDOWN
						</p>
						<div class="space-y-3">
							<div class="flex items-center justify-between border-b border-border pb-3">
								<span class="font-mono text-xs text-muted">Principal (encrypted)</span>
								<span class="font-mono text-xs text-muted">●●●● USDC</span>
							</div>
							{#if invoice.discountRateBps}
								<div class="flex items-center justify-between border-b border-border pb-3">
									<span class="font-mono text-xs text-muted"
										>Financing fee ({(invoice.discountRateBps / 100).toFixed(2)}%)</span
									>
									<span class="font-mono text-xs text-muted">●●●● USDC</span>
								</div>
							{/if}
							<div class="flex items-center justify-between pt-1">
								<span class="font-mono text-xs font-medium text-ink">Total Settlement</span>
								{#if invoice.repayAmount !== null}
									<span class="font-mono text-sm font-medium text-ink"
										>{formatUSDC(invoice.repayAmount)}</span
									>
								{:else}
									<span class="font-mono text-xs text-muted">Computing…</span>
								{/if}
							</div>
						</div>
					</div>

					<!-- Cryptographic routing -->
					<div class="border border-border p-5">
						<p class="mb-3 font-mono text-[10px] tracking-widest text-muted">
							CRYPTOGRAPHIC ROUTING
						</p>
						<div class="space-y-2">
							<div>
								<p class="mb-0.5 font-mono text-[9px] text-muted">LENDER ADDRESS</p>
								<p class="font-mono text-[10px] break-all text-ink">{shortAddr(invoice.lender)}</p>
							</div>
							{#if invoice.advanceRateBps}
								<div>
									<p class="mb-0.5 font-mono text-[9px] text-muted">ADVANCE RATE</p>
									<p class="font-mono text-[10px] text-ink">
										{(invoice.advanceRateBps / 100).toFixed(1)}%
									</p>
								</div>
							{/if}
						</div>
					</div>

					<!-- Token burn status -->
					<div class="border border-border p-5">
						<p class="mb-3 font-mono text-[10px] tracking-widest text-muted">TOKEN BURN STATUS</p>
						<div class="mb-2 h-2 w-full overflow-hidden rounded-none bg-border">
							<div
								class="h-full bg-accent transition-all"
								style="width: {invoice.settlementReady
									? '75%'
									: invoice.settlementRequested
										? '40%'
										: '10%'}"
							></div>
						</div>
						<p class="font-mono text-[10px] text-muted">
							{invoice.settlementReady ? '75%' : invoice.settlementRequested ? '40%' : '10%'} · ERC-1155
							BURN ON COMPLETION
						</p>
					</div>
				</div>

				<!-- Right: Actions + audit -->
				<div class="space-y-5">
					<!-- Action panel -->
					<div class="border border-border p-5">
						<p class="mb-4 font-mono text-[10px] tracking-widest text-muted">REPAYMENT ACTIONS</p>

						{#if error}
							<div class="mb-4 border border-accent/40 bg-accent/5 px-4 py-3">
								<p class="font-mono text-xs text-accent">{error}</p>
							</div>
						{/if}

						{#if isWorking}
							<div class="mb-4 flex items-center gap-2">
								<div
									class="h-3 w-3 animate-spin rounded-full border border-ink border-t-transparent"
								></div>
								<p class="font-mono text-[10px] text-muted">{step}</p>
							</div>
						{/if}

						{#if !invoice.settlementRequested}
							<p class="mb-4 font-mono text-[10px] text-muted">
								Initiate the FHE settlement computation to determine your exact repayment amount.
							</p>
							<button
								onclick={handleRequestSettlement}
								disabled={isWorking}
								class="w-full bg-ink px-6 py-3 font-mono text-xs tracking-widest text-paper transition-opacity hover:opacity-80 disabled:cursor-not-allowed disabled:opacity-40"
							>
								INITIATE SETTLEMENT
							</button>
						{:else if !invoice.settlementReady}
							<p class="mb-4 font-mono text-[10px] text-muted">
								Settlement amount is being computed by the FHE coprocessor. Finalize to reveal the
								exact figure.
							</p>
							<button
								onclick={handleFinalizeSettlement}
								disabled={isWorking}
								class="w-full border border-ink px-6 py-3 font-mono text-xs tracking-widest text-ink transition-colors hover:bg-ink hover:text-paper disabled:cursor-not-allowed disabled:opacity-40"
							>
								FINALIZE AMOUNT
							</button>
						{:else if invoice.repayAmount !== null}
							<p class="mb-2 font-mono text-[10px] text-muted">Repayment amount confirmed:</p>
							<p class="mb-4 font-display text-2xl text-ink">{formatUSDC(invoice.repayAmount)}</p>
							<div class="flex gap-3">
								<button
									onclick={handleRepay}
									disabled={isWorking}
									class="flex-1 bg-ink px-6 py-3 font-mono text-xs tracking-widest text-paper transition-opacity hover:opacity-80 disabled:cursor-not-allowed disabled:opacity-40"
								>
									REPAY ADVANCE
								</button>
								<button
									type="button"
									class="border border-border px-4 py-3 font-mono text-xs tracking-widest text-muted transition-colors hover:border-ink hover:text-ink"
								>
									DOWNLOAD LEDGER
								</button>
							</div>
						{/if}

						{#if lastTxHash}
							<a
								href={`${EXPLORER}${lastTxHash}`}
								target="_blank"
								rel="noopener noreferrer"
								class="mt-3 inline-block font-mono text-[10px] text-muted transition-colors hover:text-teal"
							>
								VIEW ON EXPLORER ↗
							</a>
						{/if}
					</div>

					<!-- Audit trail -->
					<div class="border border-border p-5">
						<p class="mb-3 font-mono text-[10px] tracking-widest text-muted">AUDIT TRAIL</p>
						<div class="space-y-2">
							<div class="flex items-center gap-2">
								<span class="font-mono text-[9px] {invoice.active ? 'text-teal' : 'text-muted'}"
									>✓</span
								>
								<span class="font-mono text-[10px] text-muted">Invoice submitted & tokenized</span>
							</div>
							<div class="flex items-center gap-2">
								<span class="font-mono text-[9px] {invoice.scoreReady ? 'text-teal' : 'text-muted'}"
									>{invoice.scoreReady ? '✓' : '○'}</span
								>
								<span class="font-mono text-[10px] text-muted">FHE credit score computed</span>
							</div>
							<div class="flex items-center gap-2">
								<span class="font-mono text-[9px] {invoice.funded ? 'text-teal' : 'text-muted'}"
									>{invoice.funded ? '✓' : '○'}</span
								>
								<span class="font-mono text-[10px] text-muted">Advance funded by lender</span>
							</div>
							<div class="flex items-center gap-2">
								<span
									class="font-mono text-[9px] {invoice.settlementRequested
										? 'text-teal'
										: 'text-muted'}">{invoice.settlementRequested ? '✓' : '○'}</span
								>
								<span class="font-mono text-[10px] text-muted">Settlement initiated</span>
							</div>
							<div class="flex items-center gap-2">
								<span class="font-mono text-[9px] {invoice.settled ? 'text-teal' : 'text-muted'}"
									>{invoice.settled ? '✓' : '○'}</span
								>
								<span class="font-mono text-[10px] text-muted"
									>Repayment complete · token burned</span
								>
							</div>
						</div>
						<p class="mt-4 font-mono text-[9px] break-all text-muted">
							HASH: 0x{invoice.tokenId.toString(16).padStart(64, '0')}…
						</p>
					</div>
				</div>
			</div>
		{/if}
	</div>
</div>
