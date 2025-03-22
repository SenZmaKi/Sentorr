import { get, writable } from "svelte/store";
import { paused } from "../../common/store";

export const showControlsTimedOut = writable(true);
export const isHovering = writable(false);

let hideTimer: Timer | undefined = undefined;

function clearHideTimer() {
  if (hideTimer) {
    clearTimeout(hideTimer);
    hideTimer = undefined;
    showControlsTimedOut.set(false);
  }
}

export function showControlsWithTimeout() {
  if (get(paused) || get(isHovering)) return;
  clearHideTimer();
  hideTimer = setTimeout(() => {
    showControlsTimedOut.set(true);
  }, 3_000);
}
