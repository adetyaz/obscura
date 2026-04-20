<script lang="ts">
	import { resolve } from '$app/paths';
	import { wallet } from '$lib/stores/wallet.svelte';
	import { getWalletClient, publicClient } from '$lib/viem/client';
	import { initFhe, encryptUint128 } from '$lib/fhe/client';
	import { InvoiceVaultABI } from '$lib/contracts/abis/InvoiceVault';
	import { CredentialRegistryABI } from '$lib/contracts/abis/CredentialRegistry';
	import { ADDRESSES } from '$lib/contracts/addresses';
	import { toHex, stringToBytes } from 'viem';

	// Step flow: 'kyc' → 'invoice' → 'done'
	let flowStep = $state<'kyc' | 'invoice' | 'done'>('kyc');

	// KYC state
	let isVerifyingKYC = $state(false);
	let kycError = $state('');
	let kycTxHash = $state<`0x${string}` | null>(null);
	let kycDone = $state(false);

	// Invoice form state
	let amount = $state<number | string>('');
	let buyerName = $state('');
	let dueDate = $state('');
	let isSubmitting = $state(false);
	let invoiceError = $state('');
	let invoiceStep = $state('');
	let txHash = $state<`0x${string}` | null>(null);

	const EXPLORER = 'https://sepolia.basescan.org/tx/';

	type EncStage = { label: string; status: 'idle' | 'active' | 'done' | 'error' };

	let encStages = $state<EncStage[]>([
		{ label: 'INIT FHE COPROCESSOR', status: 'idle' },
		{ label: 'ENCRYPT INVOICE AMOUNT', status: 'idle' },
		{ label: 'ENCRYPT MATURITY DATE', status: 'idle' },
		{ label: 'SUBMIT TO RETAIL POOL', status: 'idle' }
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

	// Check if address already has KYC
	$effect(() => {
		if (wallet.isConnected && wallet.address) {
			publicClient
				.readContract({
					address: ADDRESSES.CredentialRegistry,
					abi: CredentialRegistryABI,
					functionName: 'isVerifiedKYC',
					args: [wallet.address]
				})
				.then((ok) => {
					if (ok) {
						kycDone = true;
						flowStep = 'invoice';
					}
				})
				.catch(() => {});
		}
	});

	async function handleSelfVerifyKYC() {
		if (!wallet.address) {
			kycError = 'Wallet not connected.';
			return;
		}
		isVerifyingKYC = true;
		kycError = '';
		try {
			const walletClient = getWalletClient();
			const [account] = await walletClient.getAddresses();

			const hash = await walletClient.writeContract({
				address: ADDRESSES.CredentialRegistry,
				abi: CredentialRegistryABI,
				functionName: 'selfVerifyKYC',
				args: [],
				account
			});

			await publicClient.waitForTransactionReceipt({ hash });
			kycTxHash = hash;
			kycDone = true;
			flowStep = 'invoice';
		} catch (e: unknown) {
			const msg = e instanceof Error ? e.message : 'Transaction failed';
			if (msg.includes('user rejected')) {
				kycError = 'Transaction rejected.';
			} else {
				kycError = msg.slice(0, 120);
			}
		} finally {
			isVerifyingKYC = false;
		}
	}

	async function submitFreelancerInvoice() {
		if (!String(amount).trim() || !buyerName.trim() || !dueDate.trim()) {
			invoiceError = 'Amount, client name, and due date are required.';
			return;
		}
		const amountNum = parseFloat(String(amount));
		if (isNaN(amountNum) || amountNum <= 0) {
			invoiceError = 'Amount must be a positive number.';
			return;
		}
		if (amountNum > 50000) {
			invoiceError = 'Retail pool limit is $50,000. For larger amounts, use the Corporate track.';
			return;
		}
		if (!wallet.address) {
			invoiceError = 'Wallet not connected.';
			return;
		}

		isSubmitting = true;
		invoiceError = '';
		encStages = encStages.map((s) => ({ ...s, status: 'idle' }));

		try {
			setStage(0, 'active');
			invoiceStep = 'Initializing FHE coprocessor…';
			await initFhe();
			setStage(0, 'done');

			setStage(1, 'active');
			invoiceStep = 'Encrypting invoice amount…';
			const amountWei = BigInt(Math.round(amountNum * 1e6));
			const encAmount = await encryptUint128(amountWei);
			setStage(1, 'done');

			setStage(2, 'active');
			invoiceStep = 'Encrypting maturity date…';
			const dueDateTimestamp = BigInt(Math.floor(new Date(dueDate).getTime() / 1000));
			const encDueDate = await encryptUint128(dueDateTimestamp);
			setStage(2, 'done');

			setStage(3, 'active');
			invoiceStep = 'Submitting to Retail Pool…';
			const buyerBytes = toHex(stringToBytes(buyerName.trim()));
			const walletClient = getWalletClient();
			const [account] = await walletClient.getAddresses();

			const { request } = await publicClient.simulateContract({
				address: ADDRESSES.InvoiceVault,
				abi: InvoiceVaultABI,
				functionName: 'submitFreelancerInvoice',
				args: [encAmount, encDueDate, buyerBytes] as const,
				account
			});

			txHash = await walletClient.writeContract(request);
			setStage(3, 'done');

			flowStep = 'done';
			invoiceStep = '';
		} catch (e: unknown) {
			const msg = e instanceof Error ? e.message : 'Transaction failed';
			const activeIdx = encStages.findIndex((s) => s.status === 'active');
			if (activeIdx >= 0) setStage(activeIdx, 'error');

			if (msg.includes('caller not verified') || msg.includes('KYC')) {
				invoiceError = 'KYC verification required. Please complete Step 1 first.';
			} else if (msg.includes('user rejected')) {
				invoiceError = 'Transaction was rejected.';
			} else {
				invoiceError = msg.slice(0, 120);
			}
		} finally {
			isSubmitting = false;
			if (flowStep !== 'done') invoiceStep = '';
		}
	}
</script>

<div class="min-h-screen bg-paper px-8 py-10">
	<!-- Nav -->
	<div class="mb-8 flex items-center gap-3">
		<a href={resolve('/')} class="font-mono text-xs tracking-widest text-muted hover:text-ink">
			← HOME
		</a>
		<span class="font-mono text-xs text-border">/</span>
		<span class="font-mono text-xs tracking-widest text-ink">FREELANCER PORTAL</span>
	</div>

	{#if !wallet.isConnected}
		<div class="py-24 text-center">
			<p class="mb-3 font-mono text-[10px] tracking-widest text-muted">WALLET REQUIRED</p>
			<h1 class="mb-4 font-display text-3xl text-ink">Freelancer Invoice Financing</h1>
			<p class="mx-auto mb-8 max-w-md font-mono text-xs text-muted">
				Connect your wallet to verify your identity and submit invoices to the Retail Pool.
			</p>
		</div>
	{:else if flowStep === 'done'}
		<!-- Success -->
		<div class="mx-auto max-w-xl">
			<div class="border border-teal p-8">
				<p class="mb-2 font-mono text-[10px] tracking-widest text-teal">RETAIL POOL ✓</p>
				<h1 class="mb-3 font-display text-3xl text-ink">Invoice Submitted</h1>
				<div
					class="mb-4 inline-block rounded-full border border-teal px-3 py-1 font-mono text-[10px] tracking-wide text-teal"
				>
					RETAIL TIER · KYC VERIFIED
				</div>
				<p class="mb-4 font-mono text-xs text-muted">
					Your freelance invoice has been FHE-encrypted and submitted to the Retail Pool. Lenders
					can now score and fund your position.
				</p>
				{#if txHash}
					<a
						href={`${EXPLORER}${txHash}`}
						target="_blank"
						rel="noopener noreferrer"
						class="mb-6 block font-mono text-[10px] text-teal hover:underline"
					>
						VIEW TRANSACTION ↗
					</a>
				{/if}
				<div class="flex gap-3">
					<button
						onclick={() => {
							flowStep = 'invoice';
							amount = '';
							buyerName = '';
							dueDate = '';
							txHash = null;
							encStages = encStages.map((s) => ({ ...s, status: 'idle' }));
						}}
						class="border border-ink px-4 py-2.5 font-mono text-xs tracking-widest text-ink hover:bg-ink hover:text-paper"
					>
						SUBMIT ANOTHER
					</button>
					<a
						href={resolve('/')}
						class="bg-ink px-4 py-2.5 font-mono text-xs tracking-widest text-paper hover:opacity-80"
					>
						GO HOME
					</a>
				</div>
			</div>
		</div>
	{:else}
		<div class="mx-auto max-w-2xl">
			<div class="mb-6">
				<p class="mb-1 font-mono text-[10px] tracking-widest text-muted">RETAIL POOL</p>
				<h1 class="font-display text-3xl text-ink">Freelancer Portal</h1>
				<p class="mt-2 font-mono text-xs text-muted">
					KYC individual verification · Invoices up to $50,000 · FHE encrypted
				</p>
			</div>

			<!-- Step indicator -->
			<div class="mb-6 flex items-center gap-0">
				<div
					class="flex items-center gap-2 px-4 py-2 {flowStep === 'kyc'
						? 'bg-ink text-paper'
						: 'bg-teal/10 text-teal'} font-mono text-[9px] tracking-widest"
				>
					{flowStep !== 'kyc' ? '✓' : '01'}
					KYC VERIFY
				</div>
				<div class="h-px w-4 bg-border"></div>
				<div
					class="flex items-center gap-2 px-4 py-2 {flowStep === 'invoice'
						? 'bg-ink text-paper'
						: 'border border-border bg-paper text-muted'} font-mono text-[9px] tracking-widest"
				>
					02 SUBMIT INVOICE
				</div>
			</div>

			{#if flowStep === 'kyc'}
				<!-- KYC Step -->
				<div class="border border-border p-6">
					<p class="mb-2 font-mono text-[10px] tracking-widest text-muted">
						STEP 1 — IDENTITY VERIFICATION
					</p>
					<h2 class="mb-3 font-display text-xl text-ink">KYC Individual Verification</h2>
					<p class="mb-5 font-mono text-xs text-muted">
						Freelancers self-attest their identity on-chain. This records a
						<span class="text-ink">KYC_INDIVIDUAL</span> credential in the Credential Registry, enabling
						access to the Retail Invoice Pool.
					</p>

					<div class="mb-5 grid grid-cols-3 gap-px border border-border bg-border">
						<div class="bg-paper px-4 py-3">
							<p class="mb-1 font-mono text-[9px] text-muted">POOL</p>
							<p class="font-mono text-[10px] text-ink">RETAIL</p>
						</div>
						<div class="bg-paper px-4 py-3">
							<p class="mb-1 font-mono text-[9px] text-muted">MAX ADVANCE</p>
							<p class="font-mono text-[10px] text-ink">$50,000</p>
						</div>
						<div class="bg-paper px-4 py-3">
							<p class="mb-1 font-mono text-[9px] text-muted">CREDENTIAL</p>
							<p class="font-mono text-[10px] text-teal">KYC_INDIVIDUAL</p>
						</div>
					</div>

					{#if kycError}
						<p class="mb-3 font-mono text-[10px] text-accent">{kycError}</p>
					{/if}

					<button
						onclick={handleSelfVerifyKYC}
						disabled={isVerifyingKYC}
						class="w-full bg-ink py-3 font-mono text-xs tracking-widest text-paper transition-opacity hover:opacity-80 disabled:opacity-40"
					>
						{isVerifyingKYC ? 'VERIFYING ON-CHAIN…' : 'VERIFY MY IDENTITY'}
					</button>

					{#if kycTxHash}
						<a
							href={`${EXPLORER}${kycTxHash}`}
							target="_blank"
							rel="noopener noreferrer"
							class="mt-3 block text-center font-mono text-[9px] text-teal hover:underline"
						>
							KYC TX ↗
						</a>
					{/if}
				</div>
			{:else if flowStep === 'invoice'}
				<!-- Invoice Step -->
				<div>
					<!-- KYC confirmed badge -->
					<div class="mb-4 flex items-center gap-2">
						<span
							class="rounded-full bg-teal/10 px-2 py-0.5 font-mono text-[9px] tracking-wide text-teal"
						>
							KYC VERIFIED ✓
						</span>
						<span class="font-mono text-[9px] text-muted">RETAIL POOL ACCESS GRANTED</span>
					</div>

					<!-- FHE pipeline -->
					<div class="mb-5 border border-border p-5">
						<p class="mb-3 font-mono text-[9px] tracking-widest text-muted">
							FHE ENCRYPTION PIPELINE
						</p>
						<div class="space-y-1.5">
							{#each encStages as stage}
								<div class="flex items-center gap-2">
									<span class="font-mono text-[10px] {stageColor(stage.status)}">
										{stageIcon(stage.status)}
									</span>
									<span class="font-mono text-[10px] {stageColor(stage.status)}">{stage.label}</span
									>
								</div>
							{/each}
						</div>
					</div>

					<!-- Form -->
					<form
						onsubmit={(e) => {
							e.preventDefault();
							submitFreelancerInvoice();
						}}
						class="space-y-5 border border-border p-6"
					>
						<div>
							<label
								for="amount"
								class="mb-1 block font-mono text-[10px] tracking-widest text-muted"
							>
								INVOICE AMOUNT (USDC)
							</label>
							<input
								id="amount"
								type="number"
								min="0.01"
								max="50000"
								step="0.01"
								placeholder="5000.00"
								bind:value={amount}
								disabled={isSubmitting}
								class="w-full border border-border bg-paper px-3 py-2 font-mono text-sm text-ink outline-none focus:border-ink disabled:opacity-50"
							/>
							<p class="mt-1 font-mono text-[10px] text-muted">
								Max $50,000 per invoice (Retail Pool)
							</p>
						</div>

						<div>
							<label
								for="buyer-name"
								class="mb-1 block font-mono text-[10px] tracking-widest text-muted"
							>
								CLIENT NAME
							</label>
							<input
								id="buyer-name"
								type="text"
								placeholder="Acme Corp"
								bind:value={buyerName}
								disabled={isSubmitting}
								class="w-full border border-border bg-paper px-3 py-2 font-mono text-sm text-ink outline-none focus:border-ink disabled:opacity-50"
							/>
						</div>

						<div>
							<label
								for="due-date"
								class="mb-1 block font-mono text-[10px] tracking-widest text-muted"
							>
								PAYMENT DUE DATE
							</label>
							<input
								id="due-date"
								type="date"
								min={getMinDate()}
								bind:value={dueDate}
								disabled={isSubmitting}
								class="w-full border border-border bg-paper px-3 py-2 font-mono text-sm text-ink outline-none focus:border-ink disabled:opacity-50"
							/>
						</div>

						{#if invoiceError}
							<p class="font-mono text-[10px] text-accent">{invoiceError}</p>
						{/if}

						{#if invoiceStep}
							<p class="font-mono text-[10px] text-muted">{invoiceStep}</p>
						{/if}

						<button
							type="submit"
							disabled={isSubmitting}
							class="w-full bg-ink py-3 font-mono text-xs tracking-widest text-paper transition-opacity hover:opacity-80 disabled:opacity-40"
						>
							{isSubmitting ? 'ENCRYPTING & SUBMITTING…' : 'SUBMIT TO RETAIL POOL'}
						</button>
					</form>
				</div>
			{/if}
		</div>
	{/if}
</div>
