import { writable } from "svelte/store";

export const showModal = writable(false);
export const icon = writable<HTMLDivElement | undefined>(undefined);
