import { InvalidStateError } from "@/common/types";

export type ThumbnailGenerator = ReturnType<typeof createThumbnailGenerator>;

export function createThumbnailGenerator(video: HTMLVideoElement, width = 180) {
  const thumbnailVideo = document.createElement("video");
  thumbnailVideo.src = video.src;
  thumbnailVideo.crossOrigin = "anonymous";
  const thumbnailCanvas = document.createElement("canvas");
  thumbnailCanvas.width = width;
  thumbnailCanvas.height =
    thumbnailCanvas.width * (video.videoHeight / video.videoWidth) || 100;
  const thumbnailCtx = thumbnailCanvas.getContext("2d");
  if (!thumbnailCtx)
    throw new InvalidStateError("Failed to get thumbnailCanvas 2d context");
  const loadingMetadata = new Promise<void>((resolve) => {
    thumbnailVideo.onloadedmetadata = () => resolve();
  });

  async function getThumbnail(seekPercent: number): Promise<string> {
    if (!thumbnailCtx) return "";
    return new Promise(async (resolve) => {
      await loadingMetadata;
      const seekTime = (seekPercent / 100) * thumbnailVideo.duration;
      thumbnailVideo.currentTime = seekTime;

      const onSeeked = async () => {
        thumbnailVideo.removeEventListener("seeked", onSeeked);

        thumbnailCtx.drawImage(
          thumbnailVideo,
          0,
          0,
          thumbnailCanvas.width,
          thumbnailCanvas.height
        );
        const url = await new Promise<string>((resolve, reject) => {
          thumbnailCanvas.toBlob((blob: Blob | null) => {
            if (!blob)
              return reject(
                new InvalidStateError(
                  "Failed to create blob from thumbnailCanvas"
                )
              );
            resolve(URL.createObjectURL(blob));
          });
        });
        resolve(url);
      };

      thumbnailVideo.addEventListener("seeked", onSeeked);
    });
  }

  function disposeThumbnail(thumbnail: string) {
    thumbnail && URL.revokeObjectURL(thumbnail);
  }

  return {
    getThumbnail,
    disposeThumbnail,
    height: thumbnailCanvas.height,
    width: thumbnailCanvas.width,
  };
}
