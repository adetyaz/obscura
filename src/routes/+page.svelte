<script lang="ts">
	import { goto } from '$app/navigation';
	import { wallet } from '$lib/stores/wallet.svelte';

	function selectRole(role: 'sme' | 'lender') {
		wallet.setRole(role);
		goto(`/${role}`);
	}
</script>

<div class="mx-auto max-w-6xl px-6">
	<!-- Hero -->
	<section class="border-b border-border py-24">
		<p class="mb-4 font-mono text-xs tracking-widest text-muted">01 — PROTOCOL</p>
		<h1 class="mb-6 max-w-2xl font-display text-5xl leading-tight text-ink">
			Private credit infrastructure for SME invoices
		</h1>
		<p class="max-w-lg font-body text-lg leading-relaxed text-muted">
			Tokenize unpaid invoices as encrypted real-world assets. Finance them without exposing
			underlying data. Everything runs through FHE — no plaintext ever hits the chain.
		</p>
	</section>

	<!-- Role Selection -->
	<section class="py-16">
		<p class="mb-8 font-mono text-xs tracking-widest text-muted">02 — SELECT ROLE</p>

		{#if !wallet.isConnected}
			<div class="border border-border p-8">
				<p class="mb-4 font-body text-muted">Connect your wallet to get started.</p>
				<button
					onclick={wallet.connect}
					disabled={wallet.isConnecting}
					class="border border-ink bg-ink px-6 py-3 font-mono text-xs tracking-wide text-paper transition-colors hover:bg-transparent hover:text-ink disabled:opacity-50"
				>
					{wallet.isConnecting ? 'CONNECTING…' : 'CONNECT WALLET'}
				</button>
			</div>
		{:else}
			<div class="grid grid-cols-1 gap-6 md:grid-cols-2">
				<!-- SME Card -->
				<button
					onclick={() => selectRole('sme')}
					class="group border border-border p-8 text-left transition-colors hover:border-ink"
				>
					<p class="mb-2 font-mono text-xs tracking-widest text-muted">BORROWER</p>
					<h2 class="mb-3 font-display text-2xl text-ink">SME Dashboard</h2>
					<p class="mb-6 text-sm leading-relaxed text-muted">
						Submit invoices, get them encrypted and scored, receive USDC advances against your
						receivables.
					</p>
					<span
						class="inline-block border-b border-ink pb-0.5 font-mono text-xs tracking-wide text-ink transition-colors group-hover:border-accent group-hover:text-accent"
					>
						ENTER →
					</span>
				</button>

				<!-- Lender Card -->
				<button
					onclick={() => selectRole('lender')}
					class="group border border-border p-8 text-left transition-colors hover:border-ink"
				>
					<p class="mb-2 font-mono text-xs tracking-widest text-muted">INVESTOR</p>
					<h2 class="mb-3 font-display text-2xl text-ink">Lender Dashboard</h2>
					<p class="mb-6 text-sm leading-relaxed text-muted">
						Browse risk-scored invoices, fund positions, earn yield — without ever seeing the
						underlying data.
					</p>
					<span
						class="inline-block border-b border-ink pb-0.5 font-mono text-xs tracking-wide text-ink transition-colors group-hover:border-accent group-hover:text-accent"
					>
						ENTER →
					</span>
				</button>
			</div>
		{/if}
	</section>

	<!-- Footer -->
	<footer class="border-t border-border py-8">
		<p class="font-mono text-[10px] tracking-widest text-muted">
			OBSCURA PROTOCOL · WAVE 1 · BASE SEPOLIA · FHENIX COFHE
		</p>
	</footer>
</div>
