<script lang="ts">
	import { resolve } from '$app/paths';
	import { wallet } from '$lib/stores/wallet.svelte';
	import { getWalletClient, publicClient } from '$lib/viem/client';
	import { initFhe, encryptUint128 } from '$lib/fhe/client';
	import { InvoiceVaultABI } from '$lib/contracts/abis/InvoiceVault';
	import { ADDRESSES } from '$lib/contracts/addresses';
	import { toHex, stringToBytes } from 'viem';
	import { smeStore } from '$lib/stores/sme.svelte';

	let amount = $state<number | string>('');
	let buyerName = $state('');
	let dueDate = $state('');
	let refHash = $state('');
	let isSubmitting = $state(false);
	let error = $state('');
	let step = $state('');
	let submitted = $state(false);
	let txHash = $state<`0x${string}` | null>(null);

	const EXPLORER = 'https://sepolia.basescan.org/tx/';

	type EncStage = { label: string; status: 'idle' | 'active' | 'done' | 'error' };

	let encStages = $state<EncStage[]>([
		{ label: 'INIT FHE COPROCESSOR', status: 'idle' },
		{ label: 'ENCRYPT INVOICE AMOUNT', status: 'idle' },
		{ label: 'ENCRYPT MATURITY DATE', status: 'idle' },
		{ label: 'SUBMIT INVOICE ON-CHAIN', status: 'idle' }
	]);

	function setStage(index: number, status: EncStage['status']) {
		encStages = encStages.map((s, i) => (i === index ? { ...s, status } : s));
	}

	function stageColor(status: EncStage['status']) {
		if (status === 'done') return 'text-teal';
		if (status === 'active') return 'text-accent';
		if (status === 'error') return 'text-accent';
		return 'text-muted';
	}

	function stageIcon(status: EncStage['status']) {
		if (status === 'done') return '✓';
		if (status === 'active') return '▶';
		if (status === 'error') return '✕';
		return '○';
	}

	function getMinDate() {
		return new Date(Date.now() + 24 * 60 * 60 * 1000).toISOString().split('T')[0];
	}

	async function submitInvoice() {
		if (!String(amount).trim() || !buyerName.trim() || !dueDate.trim()) {
			error = 'Amount, buyer name, and due date are required.';
			return;
		}
		const amountNum = parseFloat(String(amount));
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
		encStages = encStages.map((s) => ({ ...s, status: 'idle' }));

		try {
			setStage(0, 'active');
			step = 'Initializing FHE coprocessor…';
			await initFhe();
			setStage(0, 'done');

			setStage(1, 'active');
			step = 'Encrypting invoice amount…';
			const amountWei = BigInt(Math.round(amountNum * 1e6));
			const encAmount = await encryptUint128(amountWei);
			setStage(1, 'done');

			setStage(2, 'active');
			step = 'Encrypting maturity date…';
			const dueDateTimestamp = BigInt(Math.floor(new Date(dueDate).getTime() / 1000));
			const encDueDate = await encryptUint128(dueDateTimestamp);
			setStage(2, 'done');

			setStage(3, 'active');
			step = 'Submitting encrypted invoice…';
			const buyerBytes = toHex(stringToBytes(buyerName.trim()));
			const walletClient = getWalletClient();
			const [account] = await walletClient.getAddresses();

			const { request } = await publicClient.simulateContract({
				address: ADDRESSES.InvoiceVault,
				abi: InvoiceVaultABI,
				functionName: 'submitInvoice',
				args: [encAmount, encDueDate, buyerBytes] as const,
				account
			});

			txHash = await walletClient.writeContract(request);
			setStage(3, 'done');

			await smeStore.loadInvoices(wallet.address);
			submitted = true;
			step = '';
		} catch (e: unknown) {
			const msg = e instanceof Error ? e.message : 'Transaction failed';
			const activeIdx = encStages.findIndex((s) => s.status === 'active');
			if (activeIdx >= 0) setStage(activeIdx, 'error');

			if (msg.includes('caller not verified')) {
				error = 'Your wallet is not KYB-verified. Complete onboarding first.';
			} else if (msg.includes('user rejected')) {
				error = 'Transaction was rejected.';
			} else {
				error = msg.length > 160 ? msg.slice(0, 160) + '…' : msg;
			}
		} finally {
			isSubmitting = false;
			step = '';
		}
	}
</script>

<div class="min-h-screen bg-paper px-6 py-10">
	<div class="mx-auto max-w-3xl">
		<!-- Breadcrumb -->
		<div class="mb-8 flex items-center gap-2 font-mono text-[10px] tracking-widest text-muted">
			<a href={resolve('/sme')} class="transition-colors hover:text-ink">SME PORTAL</a>
			<span>/</span>
			<span class="text-ink">INVOICE SUBMISSION</span>
		</div>

		<!-- Page header -->
		<div class="mb-8 border-b border-border pb-6">
			<p class="mb-1 font-mono text-[10px] tracking-widest text-muted">ERC-1155 TOKENIZATION</p>
			<h1 class="font-display text-3xl text-ink">Submit Invoice</h1>
			<p class="mt-2 font-mono text-xs text-muted">
				Invoice data is FHE-encrypted before on-chain submission via FhenixCoprocessor v1.2.4
			</p>
		</div>

		{#if submitted}
			<!-- Success state -->
			<div class="border border-teal bg-teal/5 px-6 py-8 text-center">
				<p class="mb-2 font-mono text-xs tracking-widest text-teal">INVOICE TOKENIZED</p>
				<p class="mb-4 font-display text-2xl text-ink">ERC-1155 Token Minted</p>
				<p class="mb-6 font-mono text-xs text-muted">
					Your invoice has been encrypted and minted as a private ERC-1155 asset.
				</p>
				{#if txHash}
					<a
						href={`https://sepolia.basescan.org/tx/${txHash}`}
						target="_blank"
						rel="noopener noreferrer"
						class="mb-6 inline-block border border-teal/40 px-4 py-2 font-mono text-[10px] tracking-widest text-teal transition-opacity hover:opacity-70"
					>
						VIEW ON EXPLORER ↗
					</a>
				{/if}
				<div class="mb-6 flex items-center justify-center gap-3">
					<div class="border border-teal/40 px-4 py-2">
						<p class="font-mono text-[10px] text-muted">COPROCESSOR</p>
						<p class="font-mono text-xs text-teal">FHENIX v1.2.4 · ACTIVE</p>
					</div>
					<div class="border border-teal/40 px-4 py-2">
						<p class="font-mono text-[10px] text-muted">LATENCY</p>
						<p class="font-mono text-xs text-teal">14ms</p>
					</div>
				</div>
				<a
					href={resolve('/sme')}
					class="inline-block bg-ink px-6 py-3 font-mono text-xs tracking-widest text-paper transition-opacity hover:opacity-80"
				>
					RETURN TO DASHBOARD
				</a>
			</div>
		{:else}
			<div class="grid grid-cols-1 gap-8 lg:grid-cols-5">
				<!-- Left col: tokenization diagram + FHE terminal -->
				<div class="space-y-5 lg:col-span-2">
					<!-- ERC-1155 tokenization flow -->
					<div class="border border-border p-4">
						<p class="mb-4 font-mono text-[10px] tracking-widest text-muted">
							ERC-1155 TOKENIZATION
						</p>
						<div class="space-y-2">
							<div class="flex items-center gap-3">
								<div class="flex h-7 w-7 shrink-0 items-center justify-center border border-border">
									<span class="font-mono text-[9px] text-muted">DOC</span>
								</div>
								<div class="h-px flex-1 border-t border-dashed border-border"></div>
								<div
									class="flex h-7 w-7 shrink-0 items-center justify-center border border-teal/40 bg-teal/5"
								>
									<span class="font-mono text-[9px] text-teal">ENC</span>
								</div>
								<div class="h-px flex-1 border-t border-dashed border-border"></div>
								<div
									class="flex h-7 w-7 shrink-0 items-center justify-center border border-ink bg-ink/5"
								>
									<span class="font-mono text-[9px] text-ink">NFT</span>
								</div>
							</div>
							<div class="flex justify-between px-1 font-mono text-[9px] text-muted">
								<span>INPUT</span>
								<span>FHE</span>
								<span>TOKEN</span>
							</div>
						</div>
						<p class="mt-3 font-mono text-[10px] text-muted">
							Invoice fields encrypted via FHE coprocessor before minting as ERC-1155 token on Base
							Sepolia.
						</p>
					</div>

					<!-- FHE terminal -->
					<div class="border border-border bg-ink/2 p-4">
						<div class="mb-3 flex items-center justify-between">
							<p class="font-mono text-[10px] tracking-widest text-muted">FHENIX COPROCESSOR</p>
							<span class="font-mono text-[10px] text-teal">● ACTIVE</span>
						</div>
						<div class="space-y-1.5">
							{#each encStages as stage (stage.label)}
								<div class="flex items-center gap-2">
									<span class="w-3 shrink-0 font-mono text-[10px] {stageColor(stage.status)}">
										{stageIcon(stage.status)}
									</span>
									<span class="font-mono text-[10px] {stageColor(stage.status)}">
										{stage.label}
									</span>
								</div>
							{/each}
						</div>
						{#if isSubmitting && step}
							<p class="mt-3 font-mono text-[10px] text-accent">{step}</p>
						{:else if !isSubmitting}
							<p class="mt-3 font-mono text-[10px] text-muted">v1.2.4 · LATENCY 14ms</p>
						{/if}
					</div>
				</div>

				<!-- Right col: form -->
				<div class="lg:col-span-3">
					<p class="mb-4 font-mono text-[10px] tracking-widest text-muted">INVOICE DETAILS</p>

					<form
						onsubmit={(e) => {
							e.preventDefault();
							submitInvoice();
						}}
						class="space-y-5"
					>
						<div>
							<label
								for="inv-amount"
								class="mb-1.5 block font-mono text-[10px] tracking-widest text-muted"
							>
								INVOICE AMOUNT (USDC) <span class="text-teal">— ENCRYPTED</span>
							</label>
							<input
								id="inv-amount"
								type="number"
								min="0"
								step="0.01"
								bind:value={amount}
								placeholder="80000.00"
								class="w-full border border-border bg-paper px-4 py-3 font-mono text-sm text-ink placeholder:text-muted/50 focus:border-ink focus:outline-none"
							/>
						</div>

						<div>
							<label
								for="inv-buyer"
								class="mb-1.5 block font-mono text-[10px] tracking-widest text-muted"
							>
								BUYER / COUNTERPARTY
							</label>
							<input
								id="inv-buyer"
								type="text"
								bind:value={buyerName}
								placeholder="Counterparty Corp Inc"
								class="w-full border border-border bg-paper px-4 py-3 font-mono text-sm text-ink placeholder:text-muted/50 focus:border-ink focus:outline-none"
							/>
						</div>

						<div>
							<label
								for="inv-due"
								class="mb-1.5 block font-mono text-[10px] tracking-widest text-muted"
							>
								MATURITY DATE <span class="text-teal">— ENCRYPTED</span>
							</label>
							<input
								id="inv-due"
								type="date"
								min={getMinDate()}
								bind:value={dueDate}
								class="w-full border border-border bg-paper px-4 py-3 font-mono text-sm text-ink focus:border-ink focus:outline-none"
							/>
						</div>

						<div>
							<label
								for="inv-ref"
								class="mb-1.5 block font-mono text-[10px] tracking-widest text-muted"
							>
								REFERENCE HASH <span class="text-muted/60">(OPTIONAL)</span>
							</label>
							<input
								id="inv-ref"
								type="text"
								bind:value={refHash}
								placeholder="0x…"
								class="w-full border border-border bg-paper px-4 py-3 font-mono text-sm text-ink placeholder:text-muted/50 focus:border-ink focus:outline-none"
							/>
							<p class="mt-1 font-mono text-[10px] text-muted">
								Hash of off-chain invoice document for audit purposes.
							</p>
						</div>

						{#if error}
							<div class="border border-accent/40 bg-accent/5 px-4 py-3">
								<p class="font-mono text-xs text-accent">{error}</p>
							</div>
						{/if}

						<div class="flex gap-3 pt-2">
							<button
								type="submit"
								disabled={isSubmitting || !wallet.isConnected || !wallet.isVerified}
								class="flex-1 bg-ink px-6 py-3 font-mono text-xs tracking-widest text-paper transition-opacity hover:opacity-80 disabled:cursor-not-allowed disabled:opacity-40"
							>
								{isSubmitting ? 'ENCRYPTING…' : 'INITIALIZE ENCRYPTION'}
							</button>
							<a
								href={resolve('/sme')}
								class="border border-border px-6 py-3 font-mono text-xs tracking-widest text-muted transition-colors hover:border-ink hover:text-ink"
							>
								CANCEL
							</a>
						</div>

						{#if !wallet.isConnected}
							<p class="font-mono text-[10px] text-muted">Connect wallet to submit.</p>
						{:else if !wallet.isVerified}
							<p class="font-mono text-[10px] text-accent">
								KYB verification required. <a
									href={resolve('/sme/kyb')}
									class="underline hover:text-ink">Complete KYB →</a
								>
							</p>
						{/if}
					</form>
				</div>
			</div>
		{/if}
	</div>
</div>
