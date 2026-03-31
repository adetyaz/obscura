import { createPublicClient, createWalletClient, custom, http } from 'viem';
import { baseSepolia } from 'viem/chains';

export const publicClient = createPublicClient({
	chain: baseSepolia,
	transport: http('https://sepolia.base.org')
});

export function getWalletClient() {
	if (typeof window === 'undefined' || !window.ethereum) {
		throw new Error('MetaMask not found');
	}
	return createWalletClient({
		chain: baseSepolia,
		transport: custom(window.ethereum)
	});
}

// Lazy — browser-only, avoids SSR crash from iframe-shared-storage
let _cofheClient: Awaited<ReturnType<typeof import('@cofhe/sdk/web')['createCofheClient']>> | null =
	null;

export async function getCofheClient() {
	if (typeof window === 'undefined') throw new Error('CofheClient is browser-only');
	if (_cofheClient) return _cofheClient;
	const { createCofheConfig, createCofheClient } = await import('@cofhe/sdk/web');
	const { chains } = await import('@cofhe/sdk/chains');
	const config = createCofheConfig({ supportedChains: [chains.baseSepolia] });
	_cofheClient = createCofheClient(config);
	return _cofheClient;
}
