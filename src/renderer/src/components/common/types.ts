export enum Page {
  Search,
  Preview,
}

export enum MediaCardType {
  Complex,
  Simple,
}

export type CompressorWorkerParams = {
  url: string;
  width: number;
  height: number;
  format?: string;
  quality?: number;
};

export type CompressorWorkerDTO = {
  params: CompressorWorkerParams
  bitmap: ImageBitmap;
};

export type CompressorWorkerResponseDTO = {
  canvasBlob: Blob;
  params: CompressorWorkerParams;
};
