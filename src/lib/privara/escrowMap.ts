const LS_ESCROW_MAP = 'obscura:wave3:token-escrow-map';

type EscrowMap = Record<string, string>;

function readMap(): EscrowMap {
	if (typeof window === 'undefined') return {};
	try {
		const raw = localStorage.getItem(LS_ESCROW_MAP);
		if (!raw) return {};
		return JSON.parse(raw) as EscrowMap;
	} catch {
		return {};
	}
}

function writeMap(map: EscrowMap) {
	if (typeof window === 'undefined') return;
	localStorage.setItem(LS_ESCROW_MAP, JSON.stringify(map));
}

export function setEscrowIdForToken(tokenId: bigint, escrowId: bigint) {
	const map = readMap();
	map[tokenId.toString()] = escrowId.toString();
	writeMap(map);
}

export function getEscrowIdForToken(tokenId: bigint): bigint | null {
	const map = readMap();
	const value = map[tokenId.toString()];
	if (!value) return null;
	try {
		return BigInt(value);
	} catch {
		return null;
	}
}
