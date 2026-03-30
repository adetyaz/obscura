<script lang="ts">
	import { wallet } from '$lib/stores/wallet.svelte';
	import { getWalletClient, publicClient } from '$lib/viem/client';
	import { CredentialRegistryABI } from '$lib/contracts/abis/CredentialRegistry';
	import { ADDRESSES } from '$lib/contracts/addresses';

	let { open = $bindable(false) } = $props();

	let businessName = $state('');
	let country = $state('');
	let isSubmitting = $state(false);
	let error = $state('');

	async function submitKYB() {
		if (!businessName.trim() || !country.trim()) {
			error = 'Please fill in all fields.';
			return;
		}

		if (!wallet.address) {
			error = 'Wallet not connected.';
			return;
		}

		isSubmitting = true;
		error = '';

		try {
			const walletClient = getWalletClient();
			const [account] = await walletClient.getAddresses();

			const { request } = await publicClient.simulateContract({
				address: ADDRESSES.CredentialRegistry,
				abi: CredentialRegistryABI,
				functionName: 'setVerified',
				args: [wallet.address, true],
				account
			});

			await walletClient.writeContract(request);
			await wallet.checkVerified();

			open = false;
			businessName = '';
			country = '';
		} catch (e: unknown) {
			const msg = e instanceof Error ? e.message : 'Transaction failed';
			if (msg.includes('caller is not the owner')) {
				error = 'Only the contract owner can verify wallets in Wave 1 mock mode.';
			} else {
				error = msg;
			}
		} finally {
			isSubmitting = false;
		}
	}

	function close() {
		if (!isSubmitting) {
			open = false;
			error = '';
		}
	}
</script>

{#if open}
	<!-- Backdrop -->
	<div class="fixed inset-0 z-40 bg-ink/40" role="presentation" onclick={close}></div>

	<!-- Modal -->
	<div class="fixed inset-0 z-50 flex items-center justify-center p-4">
		<div
			class="w-full max-w-md border border-border bg-paper"
			role="dialog"
			aria-modal="true"
			aria-labelledby="kyb-title"
			tabindex="-1"
			onclick={(e) => e.stopPropagation()}
			onkeydown={(e) => e.key === 'Escape' && close()}
		>
			<!-- Header -->
			<div class="border-b border-border px-6 py-4">
				<p class="font-mono text-[10px] tracking-widest text-muted">WAVE 1 — MOCK KYB</p>
				<h2 id="kyb-title" class="mt-1 font-display text-xl text-ink">Business Verification</h2>
			</div>

			<!-- Form -->
			<div class="px-6 py-6">
				<div class="mb-5">
					<label
						for="kyb-name"
						class="mb-1.5 block font-mono text-[10px] tracking-widest text-muted"
					>
						BUSINESS NAME
					</label>
					<input
						id="kyb-name"
						type="text"
						bind:value={businessName}
						placeholder="Acme Industries Ltd"
						disabled={isSubmitting}
						class="w-full border border-border bg-transparent px-3 py-2.5 font-body text-sm text-ink placeholder:text-muted/50 focus:border-ink focus:outline-none disabled:opacity-50"
					/>
				</div>

				<div class="mb-6">
					<label
						for="kyb-country"
						class="mb-1.5 block font-mono text-[10px] tracking-widest text-muted"
					>
						COUNTRY / JURISDICTION
					</label>
					<input
						id="kyb-country"
						type="text"
						bind:value={country}
						placeholder="Nigeria"
						disabled={isSubmitting}
						class="w-full border border-border bg-transparent px-3 py-2.5 font-body text-sm text-ink placeholder:text-muted/50 focus:border-ink focus:outline-none disabled:opacity-50"
					/>
				</div>

				{#if error}
					<p class="mb-4 font-mono text-xs text-accent">{error}</p>
				{/if}

				<div class="flex gap-3">
					<button
						onclick={close}
						disabled={isSubmitting}
						class="flex-1 border border-border px-4 py-2.5 font-mono text-xs tracking-wide text-muted transition-colors hover:border-ink hover:text-ink disabled:opacity-50"
					>
						CANCEL
					</button>
					<button
						onclick={submitKYB}
						disabled={isSubmitting || !businessName.trim() || !country.trim()}
						class="flex-1 border border-ink bg-ink px-4 py-2.5 font-mono text-xs tracking-wide text-paper transition-colors hover:bg-transparent hover:text-ink disabled:opacity-50"
					>
						{isSubmitting ? 'VERIFYING…' : 'VERIFY BUSINESS'}
					</button>
				</div>
			</div>
		</div>
	</div>
{/if}
