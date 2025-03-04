import { writable } from "svelte/store";

export let isHovering = writable(false);
export let currentTime = writable(0);
export let video = writable<HTMLVideoElement | undefined>(undefined);
