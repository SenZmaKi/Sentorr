import { InvalidStateError } from "@/common/types";

export type ThumbnailGenerator = ReturnType<typeof createThumbnailGenerator>;

export type VideoProperties = {
  src: string;
  videoHeight: number;
  videoWidth: number;
  duration: number;
};

export function createThumbnailGenerator(thumbnailWidth = 180) {
  let thumbnailVideo: HTMLVideoElement | undefined = undefined;
  let thumbnailCanvas: HTMLCanvasElement | undefined = undefined;
  let canvasCtx: CanvasRenderingContext2D | undefined = undefined;
  let thumbnailHeight: number | undefined = undefined;
  let videoProperties: VideoProperties | undefined = undefined;

  function setVideoProperties(properties: VideoProperties) {
    videoProperties = properties;
    if (!thumbnailVideo) thumbnailVideo = document.createElement("video");
    thumbnailVideo.src = properties.src;
    thumbnailVideo.crossOrigin = "anonymous";
    setCanvasDimensions();
  }

  function setCanvasDimensions() {
    if (!thumbnailCanvas || !videoProperties) return;
    thumbnailHeight =
      thumbnailWidth *
      (videoProperties.videoHeight / videoProperties.videoWidth);
    thumbnailCanvas.height = thumbnailHeight;
    thumbnailCanvas.width = thumbnailWidth;
    if (canvasCtx) return;
    const maybeCtx = thumbnailCanvas.getContext("2d");
    if (!maybeCtx)
      throw new InvalidStateError("Failed to get canvas 2d context");
    canvasCtx = maybeCtx;
  }

  function setCanvas(canvas: HTMLCanvasElement) {
    thumbnailCanvas = canvas;
    setCanvasDimensions();
  }

  async function updateThumbnail(seekPercent: number): Promise<void> {
    return new Promise(async (resolve) => {
      if (!thumbnailVideo || !videoProperties) return;
      const seekTime = (seekPercent / 100) * videoProperties.duration;
      thumbnailVideo.currentTime = seekTime;

      async function onSeeked() {
        if (!thumbnailVideo || !canvasCtx || !thumbnailCanvas) return;
        if (!canvasCtx) return;
        canvasCtx.drawImage(
          thumbnailVideo,
          0,
          0,
          thumbnailCanvas.width,
          thumbnailCanvas.height,
        );
        console.log("thumbnail updated");
        console.log("generator data", {
          thumbnailVideo,
          canvasCtx,
          thumbnailCanvas,
          thumbnailHeight,
          thumbnailWidth,
          videoProperties,
        });
        resolve();
      }

      thumbnailVideo.addEventListener("seeked", onSeeked, { once: true });
    });
  }

  return {
    updateThumbnail,
    setCanvas,
    setVideoProperties,
    thumbnailHeight,
    thumbnailWidth,
  };
}
