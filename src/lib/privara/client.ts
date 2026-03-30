/**
 * Privara SDK wrapper — Wave 1 mock
 *
 * In production this calls the real @reineira-os/sdk.
 * For the hackathon, we emit the InvoiceFunded event from FinancingPool
 * and mock the USDC disbursement here as a log + resolved promise.
 */

export async function disburseAdvance(
	recipientAddress: string,
	_amountUSDC: bigint
): Promise<{ success: boolean; txId: string }> {
	// Wave 1: mock disbursement — log and return a synthetic tx ID
	console.log(
		`[Privara] Disbursing advance to ${recipientAddress}: ${_amountUSDC.toString()} USDC (mock)`
	);

	// Simulate network delay
	await new Promise((r) => setTimeout(r, 1500));

	const mockTxId = `privara-${Date.now().toString(36)}-${Math.random().toString(36).slice(2, 8)}`;

	console.log(`[Privara] Disbursement complete — txId: ${mockTxId}`);

	return { success: true, txId: mockTxId };
}
