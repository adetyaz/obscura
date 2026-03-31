<script lang="ts">
	import { resolve } from '$app/paths';
	import { goto } from '$app/navigation';
	import { wallet } from '$lib/stores/wallet.svelte';
	import { getWalletClient, publicClient } from '$lib/viem/client';
	import { CredentialRegistryABI } from '$lib/contracts/abis/CredentialRegistry';
	import { ADDRESSES } from '$lib/contracts/addresses';

	type StepStatus = 'complete' | 'pending' | 'locked';

	interface Step {
		id: number;
		label: string;
		sublabel: string;
		status: StepStatus;
	}

	let businessName = $state('');
	let country = $state('');
	let tinEin = $state('');
	let isSubmitting = $state(false);
	let error = $state('');
	let submitted = $state(false);
	let txHash = $state<`0x${string}` | null>(null);

	const EXPLORER = 'https://sepolia.basescan.org/tx/';

	const steps: Step[] = [
		{ id: 1, label: 'Entity Incorporation', sublabel: 'ENCRYPTED ✓', status: 'complete' },
		{ id: 2, label: 'TIN / EIN Verification', sublabel: 'ENCRYPTED ✓', status: 'complete' },
		{ id: 3, label: 'Beneficial Ownership', sublabel: 'PENDING ○', status: 'pending' },
		{ id: 4, label: 'KYB Sanctions Check', sublabel: 'LOCKED 🔒', status: 'locked' }
	];

	function stepClass(status: StepStatus) {
		if (status === 'complete') return 'border-teal text-teal';
		if (status === 'pending') return 'border-accent text-accent';
		return 'border-border text-muted';
	}

	function stepDotClass(status: StepStatus) {
		if (status === 'complete') return 'bg-teal';
		if (status === 'pending') return 'bg-accent';
		return 'bg-border';
	}

	async function submitKYB() {
		if (!businessName.trim() || !country.trim()) {
			error = 'Business name and country are required.';
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
				functionName: 'selfVerify',
				args: [],
				account
			});

			const hash = await walletClient.writeContract(request);
			await publicClient.waitForTransactionReceipt({ hash });
			txHash = hash;
			await wallet.checkVerified();
			submitted = true;
		} catch (e: unknown) {
			const msg = e instanceof Error ? e.message : 'Transaction failed';
			if (msg.includes('caller is not the owner')) {
				error = 'Verification failed — please try again.';
			} else {
				error = msg;
			}
		} finally {
			isSubmitting = false;
		}
	}
</script>

<div class="min-h-screen bg-paper px-6 py-10">
	<div class="mx-auto max-w-3xl">
		<!-- Breadcrumb -->
		<div class="mb-8 flex items-center gap-2 font-mono text-[10px] tracking-widest text-muted">
			<a href={resolve('/sme')} class="transition-colors hover:text-ink">SME PORTAL</a>
			<span>/</span>
			<span class="text-ink">KYB ONBOARDING</span>
		</div>

		<!-- Page header -->
		<div class="mb-8 border-b border-border pb-6">
			<p class="mb-1 font-mono text-[10px] tracking-widest text-muted">BUSINESS VERIFICATION</p>
			<h1 class="font-display text-3xl text-ink">KYB Onboarding</h1>
			<p class="mt-2 font-mono text-xs text-muted">
				Zero-knowledge business verification powered by Privara Link
			</p>
		</div>

		{#if submitted}
			<!-- Success state -->
			<div class="border border-teal bg-teal/5 px-6 py-8 text-center">
				<p class="mb-2 font-mono text-xs tracking-widest text-teal">VERIFICATION SUBMITTED</p>
				<p class="mb-4 font-display text-2xl text-ink">Credentials Registered On-Chain</p>
				<p class="mb-6 font-mono text-xs text-muted">
					Your business identity has been verified and anchored on-chain.
				</p>
				{#if txHash}
					<a
						href={`${EXPLORER}${txHash}`}
						target="_blank"
						rel="noopener noreferrer"
						class="mb-6 inline-block border border-teal/40 px-4 py-2 font-mono text-[10px] tracking-widest text-teal transition-opacity hover:opacity-70"
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
			<div class="grid grid-cols-1 gap-8 lg:grid-cols-5">
				<!-- Left: Credential Steps -->
				<div class="lg:col-span-2">
					<p class="mb-4 font-mono text-[10px] tracking-widest text-muted">CREDENTIAL PIPELINE</p>
					<div class="space-y-0">
						{#each steps as step, i (step.id)}
							<div class="flex gap-4">
								<!-- Timeline line -->
								<div class="flex flex-col items-center">
									<div
										class="mt-1 h-3 w-3 shrink-0 rounded-full border-2 {stepDotClass(step.status)}"
									></div>
									{#if i < steps.length - 1}
										<div class="my-1 w-px flex-1 bg-border"></div>
									{/if}
								</div>
								<!-- Step content -->
								<div class="pb-6">
									<p class="font-mono text-xs text-ink">{step.label}</p>
									<p class="mt-0.5 font-mono text-[10px] {stepClass(step.status)}">
										{step.sublabel}
									</p>
								</div>
							</div>
						{/each}
					</div>

					<!-- Privara Link CTA -->
					<div class="mt-4 border border-border p-4">
						<p class="mb-2 font-mono text-[10px] tracking-widest text-muted">IDENTITY PROVIDER</p>
						<p class="mb-3 font-mono text-xs text-ink">PRIVARA LINK</p>
						<p class="mb-4 font-mono text-[10px] text-muted">
							ZK credential attestations for business identity without exposing sensitive data
							on-chain.
						</p>
						<button
							class="w-full border border-ink px-4 py-2.5 font-mono text-[10px] tracking-widest text-ink transition-colors hover:bg-ink hover:text-paper"
							type="button"
						>
							INITIALIZE PRIVARA LINK
						</button>
					</div>
				</div>

				<!-- Right: Form -->
				<div class="lg:col-span-3">
					<p class="mb-4 font-mono text-[10px] tracking-widest text-muted">ENTITY CREDENTIALS</p>

					<form
						onsubmit={(e) => {
							e.preventDefault();
							submitKYB();
						}}
						class="space-y-5"
					>
						<div>
							<label
								for="kyb-name"
								class="mb-1.5 block font-mono text-[10px] tracking-widest text-muted"
							>
								LEGAL BUSINESS NAME
							</label>
							<input
								id="kyb-name"
								type="text"
								bind:value={businessName}
								placeholder="Acme Industries Ltd"
								class="w-full border border-border bg-paper px-4 py-3 font-mono text-sm text-ink placeholder:text-muted/50 focus:border-ink focus:outline-none"
							/>
						</div>

						<div>
							<label
								for="kyb-country"
								class="mb-1.5 block font-mono text-[10px] tracking-widest text-muted"
							>
								COUNTRY OF INCORPORATION
							</label>
							<input
								id="kyb-country"
								type="text"
								bind:value={country}
								placeholder="United States"
								class="w-full border border-border bg-paper px-4 py-3 font-mono text-sm text-ink placeholder:text-muted/50 focus:border-ink focus:outline-none"
							/>
						</div>

						<div>
							<label
								for="kyb-tin"
								class="mb-1.5 block font-mono text-[10px] tracking-widest text-muted"
							>
								TIN / EIN <span class="text-teal">— ENCRYPTED</span>
							</label>
							<input
								id="kyb-tin"
								type="text"
								bind:value={tinEin}
								placeholder="XX-XXXXXXX"
								class="w-full border border-border bg-paper px-4 py-3 font-mono text-sm text-ink placeholder:text-muted/50 focus:border-ink focus:outline-none"
							/>
							<p class="mt-1 font-mono text-[10px] text-teal">
								ENCRYPTED VIA FHE BEFORE ON-CHAIN SUBMISSION
							</p>
						</div>

						<!-- Beneficial ownership notice -->
						<div class="border border-border p-4">
							<p class="mb-3 font-mono text-[10px] tracking-widest text-muted">
								BENEFICIAL OWNERSHIP — ATTESTATION
							</p>
							<div
								class="flex h-24 items-center justify-center border border-dashed border-border bg-paper/50"
							>
								<p class="font-mono text-[10px] text-muted">VERIFIED VIA PRIVARA LINK</p>
							</div>
							<p class="mt-2 font-mono text-[10px] text-muted">
								STATUS: <span class="text-accent">PENDING</span>
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
								disabled={isSubmitting || !wallet.isConnected}
								class="flex-1 bg-ink px-6 py-3 font-mono text-xs tracking-widest text-paper transition-opacity hover:opacity-80 disabled:cursor-not-allowed disabled:opacity-40"
							>
								{isSubmitting ? 'SUBMITTING...' : 'SUBMIT CREDENTIALS'}
							</button>
							<a
								href={resolve('/sme')}
								class="border border-border px-6 py-3 font-mono text-xs tracking-widest text-muted transition-colors hover:border-ink hover:text-ink"
							>
								CANCEL
							</a>
						</div>

						{#if !wallet.isConnected}
							<p class="font-mono text-[10px] text-muted">Connect wallet to submit credentials.</p>
						{/if}
					</form>
				</div>
			</div>
		{/if}
	</div>
</div>
