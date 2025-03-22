

 export function timeStamp(sec: number): string {
    const hours = Math.floor(sec / 3600);
    let minutes: string | number = Math.floor(sec / 60) - hours * 60;
    let seconds: string | number = Math.floor(sec % 60);
    if (minutes < 10 && hours > 0) minutes = "0" + minutes;
    if (seconds < 10) seconds = "0" + seconds;
    return hours > 0
      ? `${hours}:${minutes}:${seconds}`
      : `${minutes}:${seconds}`;
  }
