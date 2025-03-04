import { derived, get, writable } from "svelte/store";
import { timeStamp } from "../../../../common/functions";
import { video as videoStore, currentTime } from "../../../../common/store";
import ToastIcon from "../ToastIcon.svelte";
import { toast } from "svelte-sonner";

export let remainingTimestamp = derived(
  [currentTime, videoStore],
  ([currentTime, video]) => {
    const remainingSeconds = video?.duration ?? 0 - currentTime;
    return timeStamp(remainingSeconds);
  },
);

export let sleepTimerMins = writable<number | undefined>(undefined);
setTimeout(() => {
  sleepTimerMins.set(0.1);
}, 5000);
let sleepTimer: Timer | undefined = undefined;
sleepTimerMins.subscribe(scheduleSleepTimer);

function showSleepToast() {
  toast.info("Time to sleep", {
    icon: ToastIcon,
  });
  sleepTimerMins.set(undefined);
  clearSleepTimer();
}

function clearSleepTimer() {
  videoStore.update((video) => {
    if (video) {
      video.onended = null;
    }
    return video;
  });
  if (sleepTimer) {
    clearTimeout(sleepTimer);
    sleepTimer = undefined;
  }
}

function scheduleSleepTimer(timeMins: number | undefined) {
  clearSleepTimer();

  if (timeMins === undefined) return;

  if (timeMins === -1) {
    videoStore.update((video) => {
      if (!video) return;
      video.onended = () => {
        showSleepToast();
        return;
      };
      return video;
    });
    return;
  }

  sleepTimer = setTimeout(() => {
    const video = get(videoStore);
    if (!video) return;
    video.pause();
    showSleepToast();
  }, timeMins * 60_000);
}
