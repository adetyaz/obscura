<script lang="ts">
	import { wallet } from '$lib/stores/wallet.svelte';
	import { getWalletClient, publicClient } from '$lib/viem/client';
	import { initFhe, encryptUint128 } from '$lib/fhe/client';
	import { InvoiceVaultABI } from '$lib/contracts/abis/InvoiceVault';
	import { ADDRESSES } from '$lib/contracts/addresses';
	import { toHex, stringToBytes } from 'viem';

	let { open = $bindable(false), onsubmitted }: { open: boolean; onsubmitted?: () => void } =
		$props();

	let amount = $state('');
	let buyerName = $state('');
	let dueDate = $state('');
	let isSubmitting = $state(false);
	let error = $state('');
	let step = $state('');

	async function submitInvoice() {
		if (!amount.trim() || !buyerName.trim() || !dueDate.trim()) {
			error = 'Please fill in all fields.';
			return;
		}

		const amountNum = parseFloat(amount);
		if (isNaN(amountNum) || amountNum <= 0) {
			error = 'Amount must be a positive number.';
			return;
		}

		if (!wallet.address) {
			error = 'Wallet not connected.';
			return;
		}

		isSubmitting = true;
		error = '';

		try {
			// Step 1: Initialize FHE client
			step = 'Initializing FHE encryption…';
			await initFhe();

			// Step 2: Encrypt invoice data
			step = 'Encrypting invoice amount…';
			const amountWei = BigInt(Math.round(amountNum * 1e6)); // USDC has 6 decimals
			const encAmount = await encryptUint128(amountWei);

			step = 'Encrypting due date…';
			const dueDateTimestamp = BigInt(Math.floor(new Date(dueDate).getTime() / 1000));
			const encDueDate = await encryptUint128(dueDateTimestamp);

			// Step 3: Encode buyer name as bytes
			const buyerBytes = toHex(stringToBytes(buyerName.trim()));

			// Step 4: Submit to contract
			step = 'Submitting encrypted invoice…';
			const walletClient = getWalletClient();
			const [account] = await walletClient.getAddresses();

			const { request } = await publicClient.simulateContract({
				address: ADDRESSES.InvoiceVault,
				abi: InvoiceVaultABI,
				functionName: 'submitInvoice',
				args: [encAmount, encDueDate, buyerBytes],
				account
			});

			await walletClient.writeContract(request);

			// Success — reset and close
			step = '';
			open = false;
			amount = '';
			buyerName = '';
			dueDate = '';
			onsubmitted?.();
		} catch (e: unknown) {
			const msg = e instanceof Error ? e.message : 'Transaction failed';
			if (msg.includes('caller not verified')) {
				error = 'Your wallet is not KYB-verified.';
			} else if (msg.includes('user rejected')) {
				error = 'Transaction was rejected.';
			} else {
				error = msg.length > 120 ? msg.slice(0, 120) + '…' : msg;
			}
		} finally {
			isSubmitting = false;
			step = '';
		}
	}

	function close() {
		if (!isSubmitting) {
			open = false;
			error = '';
			step = '';
		}
	}

	function getMinDate() {
		const d = new Date();
		d.setDate(d.getDate() + 1);
		return d.toISOString().split('T')[0];
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
			aria-labelledby="invoice-title"
			tabindex="-1"
			onclick={(e) => e.stopPropagation()}
			onkeydown={(e) => e.key === 'Escape' && close()}
		>
			<!-- Header -->
			<div class="border-b border-border px-6 py-4">
				<p class="font-mono text-[10px] tracking-widest text-muted">US-02 — ENCRYPTED INVOICE</p>
				<h2 id="invoice-title" class="mt-1 font-display text-xl text-ink">Submit Invoice</h2>
			</div>

			<!-- Form -->
			<div class="px-6 py-6">
				<div class="mb-5">
					<label
						for="inv-amount"
						class="mb-1.5 block font-mono text-[10px] tracking-widest text-muted"
					>
						INVOICE AMOUNT (USDC)
					</label>
					<input
						id="inv-amount"
						type="number"
						bind:value={amount}
						placeholder="10000.00"
						min="0.01"
						step="0.01"
						disabled={isSubmitting}
						class="w-full border border-border bg-transparent px-4 py-2.5 font-mono text-sm text-ink placeholder:text-muted/50 focus:border-ink focus:outline-none disabled:opacity-50"
					/>
				</div>

				<div class="mb-5">
					<label
						for="inv-buyer"
						class="mb-1.5 block font-mono text-[10px] tracking-widest text-muted"
					>
						BUYER NAME
					</label>
					<input
						id="inv-buyer"
						type="text"
						bind:value={buyerName}
						placeholder="Globex Corporation"
						disabled={isSubmitting}
						class="w-full border border-border bg-transparent px-4 py-2.5 font-mono text-sm text-ink placeholder:text-muted/50 focus:border-ink focus:outline-none disabled:opacity-50"
					/>
				</div>

				<div class="mb-5">
					<label
						for="inv-duedate"
						class="mb-1.5 block font-mono text-[10px] tracking-widest text-muted"
					>
						DUE DATE
					</label>
					<input
						id="inv-duedate"
						type="date"
						bind:value={dueDate}
						min={getMinDate()}
						disabled={isSubmitting}
						class="w-full border border-border bg-transparent px-4 py-2.5 font-mono text-sm text-ink placeholder:text-muted/50 focus:border-ink focus:outline-none disabled:opacity-50"
					/>
				</div>

				<!-- Info box -->
				<div class="mb-5 border border-teal/20 bg-teal/5 px-4 py-3">
					<p class="font-mono text-[10px] leading-relaxed text-teal">
						All invoice data is encrypted client-side using Fhenix CoFHE before submission. Amount
						and due date are stored as FHE-encrypted values on-chain. Only authorized parties can
						decrypt.
					</p>
				</div>

				{#if error}
					<p class="mb-4 font-mono text-xs text-accent">{error}</p>
				{/if}

				{#if step}
					<div class="mb-4 flex items-center gap-2">
						<div
							class="h-3 w-3 animate-spin border border-ink border-t-transparent"
							style="border-radius: 50%;"
						></div>
						<p class="font-mono text-[10px] text-muted">{step}</p>
					</div>
				{/if}
			</div>

			<!-- Actions -->
			<div class="flex items-center justify-end gap-3 border-t border-border px-6 py-4">
				<button
					onclick={close}
					disabled={isSubmitting}
					class="px-5 py-2.5 font-mono text-xs tracking-wide text-muted transition-colors hover:text-ink disabled:opacity-50"
				>
					CANCEL
				</button>
				<button
					onclick={submitInvoice}
					disabled={isSubmitting || !amount || !buyerName || !dueDate}
					class="border border-ink bg-ink px-5 py-2.5 font-mono text-xs tracking-wide text-paper transition-colors hover:bg-transparent hover:text-ink disabled:opacity-50"
				>
					{isSubmitting ? 'ENCRYPTING…' : 'ENCRYPT & SUBMIT'}
				</button>
			</div>
		</div>
	</div>
{/if}
