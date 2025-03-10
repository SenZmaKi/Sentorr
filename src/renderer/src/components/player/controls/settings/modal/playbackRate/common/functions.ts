// https://stackoverflow.com/a/32320020/17193072
const maxPlaybackRate = 16;
const minPlaybackRate = 0.0625;
const diffPlaybackRate = maxPlaybackRate - minPlaybackRate;
const decimalPlaces = 2;

function roundUpTo5Or10(num: number, decimalPlaces: number): number {
  const decimalShift = Math.pow(10, decimalPlaces);
  const decimalPart = Math.floor((num * decimalShift) % 10); // Get decimal at decimalPlaces
  const roundedUp =
    decimalPart <= 5
      ? Math.floor(num * 10) / 10 + 0.05 // Round up to .5
      : Math.ceil(num * 10) / 10; // Round up to 1

  // Ensure returned result is to the desired decimal places cause
  // the operation above can result in a number with more decimal places
  // cause of floating point precision arithmetic
  const rounded = Math.round(roundedUp * decimalShift) / decimalShift;
  return rounded;
}

function clampRate(rate: number) {
  return Math.min(maxPlaybackRate, Math.max(minPlaybackRate, rate));
}

export function computeProgress(playbackRate: number) {
  const progress =
    ((playbackRate - minPlaybackRate) / diffPlaybackRate) * 100;
  return progress;
}

export function computePlaybackRate(progress: number) {
  const rawRate = minPlaybackRate + (diffPlaybackRate * progress) / 100;
  const roundedRate = roundUpTo5Or10(rawRate, decimalPlaces);
  const rate = clampRate(roundedRate);
  return rate;
}
