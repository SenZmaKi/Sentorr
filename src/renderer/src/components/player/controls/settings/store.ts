import type { SvelteComponent } from "svelte";
import { writable } from "svelte/store";

export const showModal = writable(false);
export const icon = writable<SvelteComponent | undefined>(undefined);
