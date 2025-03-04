export function sleepTimerToString(
  sleepTimer: number | undefined,
  remainingTimestamp: string,
) {
  if (sleepTimer === undefined) return "Off";
  if (sleepTimer === -1) return `End (${remainingTimestamp})`;
  return `${sleepTimer} mins`;
}
