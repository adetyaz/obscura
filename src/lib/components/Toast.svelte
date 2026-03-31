<script lang="ts">
	import { toast, type ToastType } from '$lib/stores/toast.svelte';
	import { fly, fade } from 'svelte/transition';

	const iconMap: Record<ToastType, string> = {
		success: '✓',
		error: '✕',
		warning: '⚠',
		info: 'ℹ'
	};
</script>

{#if toast.items.length > 0}
	<div class="fixed right-6 bottom-6 z-50 flex flex-col gap-3">
		{#each toast.items as item (item.id)}
			<div
				role="alert"
				in:fly={{ x: 80, duration: 300 }}
				out:fade={{ duration: 200 }}
				class="flex items-start gap-3 border border-border bg-paper px-4 py-3 shadow-lg"
				class:border-l-teal={item.type === 'success'}
				class:border-l-accent={item.type === 'error'}
				class:border-l-amber-600={item.type === 'warning'}
				class:border-l-muted={item.type === 'info'}
				style="border-left-width: 3px; max-width: 360px;"
			>
				<span
					class="mt-0.5 font-mono text-sm font-medium"
					class:text-teal={item.type === 'success'}
					class:text-accent={item.type === 'error'}
					class:text-amber-600={item.type === 'warning'}
					class:text-muted={item.type === 'info'}
				>
					{iconMap[item.type]}
				</span>

				<p class="flex-1 font-body text-sm leading-snug text-ink">
					{item.message}
				</p>

				<button
					onclick={() => toast.dismiss(item.id)}
					class="mt-0.5 ml-2 font-mono text-[10px] text-muted transition-colors hover:text-ink"
					aria-label="Dismiss"
				>
					✕
				</button>
			</div>
		{/each}
	</div>
{/if}
