// https://stackoverflow.com/a/32320020/17193072
const maxPlaybackSpeed = 16;
const minPlaybackSpeed = 0.0625;
const diffPlaybackSpeed = maxPlaybackSpeed - minPlaybackSpeed;
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

function clampSpeed(speed: number) {
  return Math.min(maxPlaybackSpeed, Math.max(minPlaybackSpeed, speed));
}

export function computeProgress(playbackSpeed: number) {
  const progress =
    ((playbackSpeed - minPlaybackSpeed) / diffPlaybackSpeed) * 100;
  return progress;
}

export function computePlaybackSpeed(progress: number) {
  const rawSpeed = minPlaybackSpeed + (diffPlaybackSpeed * progress) / 100;
  const roundedSpeed = roundUpTo5Or10(rawSpeed, decimalPlaces);
  const speed = clampSpeed(roundedSpeed);
  return speed;
}
