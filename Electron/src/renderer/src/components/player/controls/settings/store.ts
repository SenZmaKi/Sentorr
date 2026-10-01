import { writable } from "svelte/store";

export const showSettingsModal = writable(false);
export const icon = writable<HTMLButtonElement | undefined>(undefined);
