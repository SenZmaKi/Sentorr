import { writable } from "svelte/store";

export const isHoveringWithTimer = writable(false);
let hoveringTimer: Timer | undefined = undefined;

export function updateIsHoveringWithTimer(isHovering: boolean) {
  const initialRun = !!hoveringTimer;
  if (hoveringTimer) clearTimeout(hoveringTimer);
  if (isHovering) {
    isHoveringWithTimer.set(isHovering);
  } else {
    hoveringTimer = setTimeout(() => {
      if (!initialRun) return;

      isHoveringWithTimer.set(isHovering);
    }, 1_000);
  }
}
