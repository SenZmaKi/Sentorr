import { derived, get, writable, type Unsubscriber } from "svelte/store";
import { timeStamp } from "../../../../common/functions";
import {
  video as videoStore,
  currentTime,
  ended,
} from "../../../../../common/store";
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
let sleepTimer: Timer | undefined = undefined;
let endedUnsubscriber: Unsubscriber | undefined = undefined;
sleepTimerMins.subscribe(scheduleSleepTimer);

function showSleepToast() {
  const video = get(videoStore);
  if (video) video.pause();
  toast.info("Time to sleep", {
    icon: ToastIcon,
  });
  sleepTimerMins.set(undefined);
  clearSleepTimer();
}

function clearSleepTimer() {
  if (sleepTimer) {
    clearTimeout(sleepTimer);
    sleepTimer = undefined;
  } else if (endedUnsubscriber) {
    endedUnsubscriber();
    endedUnsubscriber = undefined;
  }
}

function scheduleSleepTimer(timeMins: number | undefined) {
  clearSleepTimer();

  if (timeMins === undefined) return;

  if (timeMins === -1) {
    endedUnsubscriber = ended.subscribe((ended) => {
      if (ended) {
        console.log("ended");
        showSleepToast();
      }
    });

    return;
  }

  sleepTimer = setTimeout(() => {
    showSleepToast();
  }, timeMins * 60_000);
}
