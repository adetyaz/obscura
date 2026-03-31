export type ToastType = 'success' | 'error' | 'info' | 'warning';

interface Toast {
	id: number;
	message: string;
	type: ToastType;
}

let nextId = 0;
let toasts = $state<Toast[]>([]);

export const toast = {
	get items() {
		return toasts;
	},

	add(message: string, type: ToastType = 'info', duration = 4000) {
		const id = nextId++;
		toasts.push({ id, message, type });
		if (duration > 0) {
			setTimeout(() => this.dismiss(id), duration);
		}
	},

	dismiss(id: number) {
		toasts = toasts.filter((t) => t.id !== id);
	},

	success(message: string, duration?: number) {
		this.add(message, 'success', duration);
	},

	error(message: string, duration?: number) {
		this.add(message, 'error', duration ?? 6000);
	},

	warning(message: string, duration?: number) {
		this.add(message, 'warning', duration ?? 5000);
	},

	info(message: string, duration?: number) {
		this.add(message, 'info', duration);
	}
};
