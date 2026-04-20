<script lang="ts">
	import { goto } from '$app/navigation';
	import { resolve } from '$app/paths';
	import { wallet } from '$lib/stores/wallet.svelte';

	const smePoints = [
		{ num: '01', text: 'Submit encrypted invoices as ERC-1155 tokens' },
		{ num: '02', text: 'Receive FHE credit score without exposing financials' },
		{ num: '03', text: 'Get USDC advance and repay on your schedule' }
	];

	const lenderPoints = [
		{ letter: 'A', text: 'Browse risk-scored invoices on the private marketplace' },
		{ letter: 'B', text: 'Fund positions and earn structured discount yield' }
	];

	function selectRole(role: 'sme' | 'lender') {
		wallet.setRole(role);
		if (role === 'sme') {
			void goto(resolve('/sme'));
		} else {
			void goto(resolve('/lender'));
		}
	}
</script>

<div class="min-h-screen bg-paper px-8 py-16">
	<div class="mx-auto max-w-5xl">
		<!-- Header -->
		<div class="mb-16">
			<a
				href={resolve('/')}
				class="mb-8 inline-block font-mono text-xs tracking-widest text-muted hover:text-ink"
			>
				← OBSCURA
			</a>
			<p class="mb-3 font-mono text-[10px] tracking-widest text-muted">SELECT ROLE</p>
			<h1 class="font-display text-5xl text-ink">How are you accessing the protocol?</h1>
		</div>

		<!-- Role cards -->
		<div class="grid grid-cols-2 gap-6">
			<!-- SME Card -->
			<button
				onclick={() => selectRole('sme')}
				class="group border border-border p-8 text-left hover:border-ink"
			>
				<div class="mb-6 flex items-center justify-between">
					<p class="font-mono text-[10px] tracking-widest text-muted">BORROWER / ORIGINATOR</p>
					<span
						class="border border-border px-2 py-0.5 font-mono text-[10px] tracking-widest text-teal group-hover:border-teal"
					>
						SME
					</span>
				</div>

				<h2 class="mb-4 font-display text-3xl text-ink">SME Dashboard</h2>
				<p class="mb-8 text-sm leading-relaxed text-muted">
					Finance your unpaid invoices through FHE-encrypted receivables financing. No counterparty
					data ever leaves your device as plaintext.
				</p>

				<div class="mb-8 space-y-3">
					{#each smePoints as point (point.num)}
						<div class="flex items-start gap-3">
							<span class="shrink-0 font-mono text-[10px] tracking-widest text-muted"
								>{point.num}</span
							>
							<span class="text-sm text-ink">{point.text}</span>
						</div>
					{/each}
				</div>

				<!-- FHE status -->
				<div class="border border-dashed border-teal/40 p-3">
					<div class="flex items-center gap-2">
						<div class="h-1.5 w-1.5 rounded-full bg-teal"></div>
						<span class="font-mono text-[10px] tracking-widest text-teal"
							>FHE COPROCESSOR ACTIVE</span
						>
					</div>
					<p class="mt-1 font-mono text-[10px] text-muted">Invoice data encrypted via cofhe/sdk</p>
				</div>

				<div class="mt-6 flex items-center justify-between">
					<span class="font-mono text-xs tracking-widest text-ink group-hover:text-accent">
						ENTER AS SME →
					</span>
				</div>
			</button>

			<!-- Lender Card -->
			<button
				onclick={() => selectRole('lender')}
				class="group border border-border p-8 text-left hover:border-ink"
			>
				<div class="mb-6 flex items-center justify-between">
					<p class="font-mono text-[10px] tracking-widest text-muted">INVESTOR / LENDER</p>
					<span
						class="border border-border px-2 py-0.5 font-mono text-[10px] tracking-widest text-ink group-hover:border-ink"
					>
						LENDER
					</span>
				</div>

				<h2 class="mb-4 font-display text-3xl text-ink">Lender Marketplace</h2>
				<p class="mb-8 text-sm leading-relaxed text-muted">
					Access a curated marketplace of cryptographically verified invoice tokens. Fund positions
					and earn yield without seeing underlying commercial data.
				</p>

				<div class="mb-8 space-y-3">
					{#each lenderPoints as point (point.letter)}
						<div class="flex items-start gap-3">
							<span class="shrink-0 font-mono text-[10px] tracking-widest text-muted"
								>[{point.letter}]</span
							>
							<span class="text-sm text-ink">{point.text}</span>
						</div>
					{/each}
				</div>

				<!-- Compliance status -->
				<div class="border border-dashed border-border p-3">
					<div class="flex items-center gap-2">
						<div class="h-1.5 w-1.5 rounded-full bg-teal"></div>
						<span class="font-mono text-[10px] tracking-widest text-teal">KYC/AML POOL ACTIVE</span>
					</div>
					<p class="mt-1 font-mono text-[10px] text-muted">
						Privara credential verification enabled
					</p>
				</div>

				<div class="mt-6 flex items-center justify-between">
					<span class="font-mono text-xs tracking-widest text-ink group-hover:text-accent">
						ENTER AS LENDER →
					</span>
				</div>
			</button>
		</div>

		<!-- Connected wallet -->
		{#if wallet.address}
			<div class="mt-8 border border-dashed border-border p-4">
				<div class="flex items-center gap-3">
					<div class="h-1.5 w-1.5 rounded-full bg-teal"></div>
					<p class="font-mono text-[10px] tracking-widest text-teal">WALLET CONNECTED</p>
					<p class="font-mono text-[10px] text-muted">{wallet.address}</p>
				</div>
			</div>
		{:else}
			<div class="mt-8 border border-dashed border-border p-4">
				<div class="flex items-center gap-4">
					<div class="h-1.5 w-1.5 rounded-full bg-accent"></div>
					<p class="font-mono text-[10px] tracking-widest text-accent">WALLET NOT CONNECTED</p>
					<button
						onclick={wallet.connect}
						disabled={wallet.isConnecting}
						class="border border-ink px-4 py-1.5 font-mono text-[10px] tracking-widest text-ink hover:bg-ink hover:text-paper disabled:opacity-50"
					>
						{wallet.isConnecting ? 'CONNECTING…' : 'CONNECT →'}
					</button>
				</div>
			</div>
		{/if}
	</div>
</div>
