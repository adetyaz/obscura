<script lang="ts">
	import { onMount } from 'svelte';
	import './layout.css';
	import { wallet } from '$lib/stores/wallet.svelte';
	import Toast from '$lib/components/Toast.svelte';
	import logo from '$lib/assets/obscura-logo.png';
	import { resolve } from '$app/paths';

	let { children } = $props();

	onMount(() => {
		wallet.restore();
	});

	function truncateAddress(addr: string) {
		return `${addr.slice(0, 6)}…${addr.slice(-4)}`;
	}
</script>

<svelte:head>
	<title>OBSCURA</title>
</svelte:head>

<div class="min-h-screen bg-paper">
	<!-- Header -->
	<header class="border-b border-border">
		<div class="mx-auto flex max-w-6xl items-center justify-between px-6 py-4">
			<!-- Logo -->
			<a href={resolve('/')}>
				<img src={logo} alt="Obscura" class="h-8 w-auto" />
			</a>

			<!-- Nav + Wallet -->
			<div class="flex items-center gap-6">
				{#if wallet.isConnected && wallet.role}
					<nav class="flex gap-4 font-mono text-xs tracking-wide text-muted">
						<a
							href={resolve('/sme')}
							class="transition-colors hover:text-ink"
							class:text-ink={wallet.role === 'sme'}
							class:font-medium={wallet.role === 'sme'}
						>
							SME
						</a>
						<a
							href={resolve('/lender')}
							class="transition-colors hover:text-ink"
							class:text-ink={wallet.role === 'lender'}
							class:font-medium={wallet.role === 'lender'}
						>
							LENDER
						</a>
					</nav>
					<span class="h-4 w-px bg-border"></span>
				{/if}

				{#if wallet.isConnected}
					<div class="flex items-center gap-3">
						{#if wallet.isVerified}
							<span
								class="rounded-full bg-teal/10 px-2 py-0.5 font-mono text-[10px] font-medium tracking-wide text-teal"
							>
								VERIFIED
							</span>
						{/if}
						<span class="font-mono text-xs text-muted">
							{truncateAddress(wallet.address!)}
						</span>
						<button
							onclick={wallet.disconnect}
							class="font-mono text-[10px] tracking-wide text-muted transition-colors hover:text-accent"
						>
							DISCONNECT
						</button>
					</div>
				{:else}
					<button
						onclick={wallet.connect}
						disabled={wallet.isConnecting}
						class="border border-ink bg-ink px-4 py-2 font-mono text-xs tracking-wide text-paper transition-colors hover:bg-transparent hover:text-ink disabled:opacity-50"
					>
						{wallet.isConnecting ? 'CONNECTING…' : 'CONNECT WALLET'}
					</button>
				{/if}
			</div>
		</div>
	</header>

	<!-- Main content -->
	<main>
		{@render children()}
	</main>

	<Toast />
</div>
