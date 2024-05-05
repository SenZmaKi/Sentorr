import type { CompressorWorkerDTO, CompressorWorkerResponseDTO } from "./types";

self.onmessage = async (msg: { data: CompressorWorkerDTO }) => {
  const { bitmap, params } = msg.data;
  const { width, height, format, url, quality } = params;
  const canvas = new OffscreenCanvas(width, height);
  const ctx = canvas.getContext("2d") as OffscreenCanvasRenderingContext2D;
  ctx.drawImage(bitmap, 0, 0, width, height);
  const innerFormat = format ?? url.split(".").pop();
  const canvasBlob = await canvas.convertToBlob({
    type: `image/${innerFormat}`,
    quality,
  });
  const response = {
    canvasBlob,
    params,
  } as CompressorWorkerResponseDTO;
  self.postMessage(response);
};
