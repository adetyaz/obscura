import { createPublicClient, createWalletClient, custom, defineChain, http } from 'viem';

export const fhenixHelium = defineChain({
	id: 8008135,
	name: 'Fhenix Helium',
	nativeCurrency: { name: 'tFHE', symbol: 'tFHE', decimals: 18 },
	rpcUrls: { default: { http: ['https://api.helium.fhenix.zone'] } },
	blockExplorers: {
		default: { name: 'Explorer', url: 'https://explorer.helium.fhenix.zone' }
	},
	testnet: true
});

export const publicClient = createPublicClient({
	chain: fhenixHelium,
	transport: http('https://api.helium.fhenix.zone')
});

export function getWalletClient() {
	if (typeof window === 'undefined' || !window.ethereum) {
		throw new Error('MetaMask not found');
	}
	return createWalletClient({
		chain: fhenixHelium,
		transport: custom(window.ethereum)
	});
}
