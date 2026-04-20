<script lang="ts">
	import { resolve } from '$app/paths';
	import { wallet } from '$lib/stores/wallet.svelte';
	import { smeStore } from '$lib/stores/sme.svelte';
	import { toHex, stringToBytes } from 'viem';

	let amount = $state<number | string>('');
	let buyerName = $state('');
	let dueDate = $state('');
	let govRefNumber = $state('');
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
		{ label: 'ENCRYPT GOVERNMENT REF', status: 'idle' },
		{ label: 'SUBMIT ON-CHAIN (GOV POOL)', status: 'idle' }
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
		if (!String(amount).trim() || !buyerName.trim() || !dueDate.trim() || !govRefNumber.trim()) {
			error = 'All fields including Government Ref # are required.';
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
			// initFhe is called inside submitGovernmentInvoice
			setStage(0, 'done');

			setStage(1, 'active');
			step = 'Preparing invoice amount…';
			const amountWei = BigInt(Math.round(amountNum * 1e6));
			setStage(1, 'done');

			setStage(2, 'active');
			step = 'Preparing maturity date…';
			const dueDateTimestamp = BigInt(Math.floor(new Date(dueDate).getTime() / 1000));
			setStage(2, 'done');

			setStage(3, 'active');
			step = 'Encrypting government reference…';
			// govRef is encoded as a numeric ID padded to uint128
			const govRefValue = BigInt(
				'0x' + Buffer.from(govRefNumber.trim().padEnd(16, '\0')).toString('hex').slice(0, 32)
			);
			setStage(3, 'done');

			setStage(4, 'active');
			step = 'Submitting to Government Invoice Pool…';
			const buyerBytes = toHex(stringToBytes(buyerName.trim())) as `0x${string}`;

			txHash = await smeStore.submitGovernmentInvoice(
				amountWei,
				dueDateTimestamp,
				buyerBytes,
				govRefValue
			);
			setStage(4, 'done');

			if (wallet.address) await smeStore.loadInvoices(wallet.address);
			submitted = true;
			step = '';
		} catch (e: unknown) {
			const msg = e instanceof Error ? e.message : 'Transaction failed';
			const activeIdx = encStages.findIndex((s) => s.status === 'active');
			if (activeIdx >= 0) setStage(activeIdx, 'error');

			if (msg.includes('caller not verified') || msg.includes('KYB')) {
				error = 'Your business must be KYB-verified to submit government invoices.';
			} else if (msg.includes('user rejected')) {
				error = 'Transaction was rejected.';
			} else {
				error = msg.slice(0, 120);
			}
		} finally {
			isSubmitting = false;
			if (!submitted) step = '';
		}
	}
</script>

<div class="min-h-screen bg-paper px-8 py-10">
	<!-- Nav -->
	<div class="mb-8 flex items-center gap-3">
		<a href={resolve('/sme')} class="font-mono text-xs tracking-widest text-muted hover:text-ink">
			← SME DASHBOARD
		</a>
		<span class="font-mono text-xs text-border">/</span>
		<span class="font-mono text-xs tracking-widest text-ink">GOVERNMENT INVOICE</span>
	</div>

	{#if submitted}
		<!-- Success state -->
		<div class="mx-auto max-w-xl">
			<div class="border border-teal p-8">
				<p class="mb-2 font-mono text-[10px] tracking-widest text-teal">GOV POOL ✓</p>
				<h1 class="mb-3 font-display text-3xl text-ink">Invoice Submitted</h1>
				<p class="mb-4 font-mono text-xs text-muted">
					Your government contract invoice has been encrypted and submitted to the Government
					Invoice Pool.
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
				<a
					href={resolve('/sme')}
					class="inline-block bg-ink px-5 py-2.5 font-mono text-xs tracking-widest text-paper hover:opacity-80"
				>
					BACK TO DASHBOARD
				</a>
			</div>
		</div>
	{:else}
		<div class="mx-auto max-w-2xl">
			<div class="mb-6">
				<p class="mb-1 font-mono text-[10px] tracking-widest text-muted">GOVERNMENT CONTRACT</p>
				<h1 class="font-display text-3xl text-ink">Submit Gov Invoice</h1>
				<div class="mt-2 flex items-center gap-2">
					<span
						class="rounded-full border border-teal px-2 py-0.5 font-mono text-[9px] tracking-wide text-teal"
					>
						GOV POOL
					</span>
					<span class="font-mono text-[10px] text-muted">KYB required · No advance cap</span>
				</div>
			</div>

			<!-- Encryption progress -->
			<div class="mb-6 border border-border p-5">
				<p class="mb-3 font-mono text-[9px] tracking-widest text-muted">FHE ENCRYPTION PIPELINE</p>
				<div class="space-y-1.5">
					{#each encStages as stage}
						<div class="flex items-center gap-2">
							<span class="font-mono text-[10px] {stageColor(stage.status)}">
								{stageIcon(stage.status)}
							</span>
							<span class="font-mono text-[10px] {stageColor(stage.status)}">{stage.label}</span>
						</div>
					{/each}
				</div>
			</div>

			<!-- Form -->
			<form
				onsubmit={(e) => {
					e.preventDefault();
					submitInvoice();
				}}
				class="space-y-5 border border-border p-6"
			>
				<div>
					<label for="amount" class="mb-1 block font-mono text-[10px] tracking-widest text-muted">
						INVOICE AMOUNT (USDC)
					</label>
					<input
						id="amount"
						type="number"
						min="0.01"
						step="0.01"
						placeholder="500000.00"
						bind:value={amount}
						disabled={isSubmitting}
						class="w-full border border-border bg-paper px-3 py-2 font-mono text-sm text-ink outline-none focus:border-ink disabled:opacity-50"
					/>
					<p class="mt-1 font-mono text-[10px] text-muted">No advance cap on government invoices</p>
				</div>

				<div>
					<label for="gov-ref" class="mb-1 block font-mono text-[10px] tracking-widest text-muted">
						GOVERNMENT CONTRACT REF #
					</label>
					<input
						id="gov-ref"
						type="text"
						placeholder="GCR-2024-001234"
						bind:value={govRefNumber}
						disabled={isSubmitting}
						class="w-full border border-border bg-paper px-3 py-2 font-mono text-sm text-ink outline-none focus:border-ink disabled:opacity-50"
					/>
					<p class="mt-1 font-mono text-[10px] text-muted">
						Encrypted on-chain — verified against known gov ref hash
					</p>
				</div>

				<div>
					<label
						for="buyer-name"
						class="mb-1 block font-mono text-[10px] tracking-widest text-muted"
					>
						CONTRACTING AUTHORITY
					</label>
					<input
						id="buyer-name"
						type="text"
						placeholder="Dept. of Transportation"
						bind:value={buyerName}
						disabled={isSubmitting}
						class="w-full border border-border bg-paper px-3 py-2 font-mono text-sm text-ink outline-none focus:border-ink disabled:opacity-50"
					/>
				</div>

				<div>
					<label for="due-date" class="mb-1 block font-mono text-[10px] tracking-widest text-muted">
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

				{#if error}
					<p class="font-mono text-[10px] text-accent">{error}</p>
				{/if}

				{#if step}
					<p class="font-mono text-[10px] text-muted">{step}</p>
				{/if}

				<button
					type="submit"
					disabled={isSubmitting}
					class="w-full bg-ink py-3 font-mono text-xs tracking-widest text-paper transition-opacity hover:opacity-80 disabled:opacity-40"
				>
					{isSubmitting ? 'ENCRYPTING & SUBMITTING…' : 'SUBMIT TO GOV POOL'}
				</button>
			</form>
		</div>
	{/if}
</div>
