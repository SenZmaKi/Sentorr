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

/**
 * WARN: To avoid flickering of the controls, set the variables that hide controls **AFTER** calling this.
 * For instance in `PlayPause.svelte`, set `paused` to `false` **AFTER** calling this function
 */
export function showControlsWithTimeout(ignorePaused = false) {
  if ((!ignorePaused && get(paused)) || get(isHovering)) return;
  clearHideTimer();
  hideTimer = setTimeout(() => {
    showControlsTimedOut.set(true);
  }, 3_000);
}
