export const ADDRESSES = {
	CredentialRegistry: '0x92Eb3f22cE51306c8eB615badbf836Ab0592eBc9' as `0x${string}`,
	InvoiceVault: '0xe31D38Cad823cF3882494bD8D4693B373C065A08' as `0x${string}`,
	CreditOracle: '0x8B6D769249e97aEefE1Bc2a60318E8297AAa7082' as `0x${string}`,
	FinancingPool: '0xf26B28407536764F397CF60E33731226c9005f54' as `0x${string}`,

	// Wave 3 slots — set these in .env as contracts are deployed
	BuyerOracle: (import.meta.env.VITE_BUYER_ORACLE_ADDRESS ?? '0x0000000000000000000000000000000000000000') as `0x${string}`,
	SelectiveDisclosure: (import.meta.env.VITE_SELECTIVE_DISCLOSURE_ADDRESS ??
		'0x0000000000000000000000000000000000000000') as `0x${string}`,
	ObscuraRepaymentGate: (import.meta.env.VITE_GATE_ADDRESS ??
		'0x0000000000000000000000000000000000000000') as `0x${string}`
} as const;
