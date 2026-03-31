<script lang="ts">
	import { resolve } from '$app/paths';
	import { wallet } from '$lib/stores/wallet.svelte';

	const stats = [
		{ label: 'TVL', value: '$492M' },
		{ label: 'ACTIVE LOANS', value: '1,249' },
		{ label: 'ZKP VALIDITY', value: '100%' },
		{ label: 'AVG YIELD', value: '8.42% APY' }
	];

	const smeFeatures = [
		{
			num: '01',
			title: 'ZK Credit Scores',
			body: 'Your creditworthiness proven on-chain without revealing raw financials. Encrypted by Fhenix CoFHE.'
		},
		{
			num: '02',
			title: 'Encrypted Collateral',
			body: 'Invoice amounts, buyer identities, and due dates remain ciphertext throughout the financing lifecycle.'
		},
		{
			num: '03',
			title: 'Non-Custodial Escrow',
			body: 'ERC-1155 invoice tokens locked in protocol-governed escrow. No intermediary holds your assets.'
		}
	];

	const lenderFeatures = [
		{
			letter: 'A',
			title: 'Verified RWA',
			body: 'Every invoice is anchored to on-chain credential proofs via Privara. Real commercial paper, cryptographically attested.'
		},
		{
			letter: 'B',
			title: 'KYC/AML Pools',
			body: 'Lender addresses screened against sanctions lists before position entry. Compliance without data leakage.'
		},
		{
			letter: 'C',
			title: 'Auto Default Protection',
			body: 'Smart contract enforces repayment schedules. Collateral released on settlement, liquidated on default.'
		}
	];

	async function handleConnect() {
		await wallet.connect();
	}
</script>

<div class="min-h-screen bg-paper">
	<!-- Hero -->
	<section class="border-b border-border px-8 py-24">
		<div class="mx-auto max-w-6xl">
			<p class="mb-6 font-mono text-[10px] tracking-widest text-muted">
				OBSCURA PROTOCOL · FHENIX COFHE · WAVE 1
			</p>
			<h1 class="mb-8 max-w-3xl font-display text-6xl leading-none text-ink">
				Privacy is the New Provenance
			</h1>
			<p class="mb-10 max-w-xl text-lg leading-relaxed text-muted">
				Encrypted invoice financing for SMEs. Verified real-world assets for lenders. No plaintext
				ever touches the chain.
			</p>
			<div class="flex items-center gap-4">
				{#if wallet.isConnected}
					<a
						href={resolve('/select')}
						class="border border-ink bg-ink px-8 py-4 font-mono text-xs tracking-widest text-paper hover:bg-ink/90"
					>
						ENTER PROTOCOL →
					</a>
					<span class="font-mono text-[10px] tracking-widest text-teal">● CONNECTED</span>
				{:else}
					<button
						onclick={handleConnect}
						disabled={wallet.isConnecting}
						class="border border-ink bg-ink px-8 py-4 font-mono text-xs tracking-widest text-paper hover:bg-ink/90 disabled:opacity-50"
					>
						{wallet.isConnecting ? 'CONNECTING…' : 'CONNECT WALLET'}
					</button>
					<span class="font-mono text-[10px] tracking-widest text-muted">
						THEN SELECT YOUR ROLE
					</span>
				{/if}
			</div>
		</div>
	</section>

	<!-- Stats ticker -->
	<section class="border-b border-border bg-ink px-8">
		<div class="mx-auto max-w-6xl">
			<div class="flex divide-x divide-ink/30">
				{#each stats as stat (stat.label)}
					<div class="flex-1 px-6 py-5">
						<p class="font-mono text-[10px] tracking-widest text-paper/50">{stat.label}</p>
						<p class="mt-1 font-display text-2xl text-paper">{stat.value}</p>
					</div>
				{/each}
			</div>
		</div>
	</section>

	<!-- For SMEs -->
	<section class="border-b border-border px-8 py-20">
		<div class="mx-auto max-w-6xl">
			<div class="mb-12 grid grid-cols-2 gap-8">
				<div>
					<p class="mb-3 font-mono text-[10px] tracking-widest text-muted">FOR SME ORIGINATORS</p>
					<h2 class="font-display text-4xl text-ink">
						Finance your receivables.<br />Keep them private.
					</h2>
				</div>
				<div class="flex items-end">
					<p class="text-muted">
						Submit invoices, receive encrypted credit scores, get USDC advances — without exposing
						counterparty data to anyone on the network.
					</p>
				</div>
			</div>
			<div class="grid grid-cols-3 gap-6">
				{#each smeFeatures as feat (feat.num)}
					<div class="border border-border p-6">
						<p class="mb-4 font-mono text-[10px] tracking-widest text-muted">{feat.num}</p>
						<h3 class="mb-3 font-display text-xl text-ink">{feat.title}</h3>
						<p class="text-sm leading-relaxed text-muted">{feat.body}</p>
					</div>
				{/each}
			</div>
		</div>
	</section>

	<!-- For Lenders -->
	<section class="border-b border-border px-8 py-20">
		<div class="mx-auto max-w-6xl">
			<div class="mb-12 grid grid-cols-2 gap-8">
				<div>
					<p class="mb-3 font-mono text-[10px] tracking-widest text-muted">
						FOR INSTITUTIONAL LENDERS
					</p>
					<h2 class="font-display text-4xl text-ink">Verified RWA.<br />Compliant yield.</h2>
				</div>
				<div class="flex items-end">
					<p class="text-muted">
						Browse risk-scored invoices on the marketplace, fund positions, and earn structured
						yield — all without seeing raw invoice data.
					</p>
				</div>
			</div>
			<div class="grid grid-cols-3 gap-6">
				{#each lenderFeatures as feat (feat.letter)}
					<div class="border border-border p-6">
						<p class="mb-4 font-mono text-[10px] tracking-widest text-muted">[{feat.letter}]</p>
						<h3 class="mb-3 font-display text-xl text-ink">{feat.title}</h3>
						<p class="text-sm leading-relaxed text-muted">{feat.body}</p>
					</div>
				{/each}
			</div>
		</div>
	</section>

	<!-- Footer -->
	<footer class="border-t border-border px-8 py-8">
		<div class="mx-auto max-w-6xl">
			<p class="font-mono text-[10px] tracking-widest text-muted">OBSCURA PROTOCOL · 2026</p>
		</div>
	</footer>
</div>
