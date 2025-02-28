export async function safePlay(video: HTMLVideoElement) {
  try {
    await video.play();
  } catch (error: any) {
    const wasPausedMsg =
      "The play() request was interrupted by a call to pause().";
    console.log(error.message);
    if (error.message.includes(wasPausedMsg)) return;
    throw error;
  }
}
