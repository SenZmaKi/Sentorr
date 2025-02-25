import { type TorrentApi } from "@/backend/torrent/api.ts";

declare global {
  export interface HTMLVideoElement {
    videoTracks: unknown[];
    audioTracks: unknown[];
  }
  interface Window {
    api: { torrent: TorrentApi };
  }
}
