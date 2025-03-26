/// <reference types="webtorrent" />

import { type Server as HttpServer } from "http";

declare module "webtorrent" {
  interface Options {
    torrentPort?: number;
  }
  interface TorrentOptions {
    deselect?: boolean;
  }

  interface Instance {
    destroyed: boolean;
    torrentPort: number;
    get(torrentId: Torrent | string | Buffer): Promise<Torrent | void>;
    on(event: "info", callback: (err: Error | string) => void): this;

    remove(
      torrentId: Torrent | string | Buffer,
      opts?: TorrentDestroyOptions,
      callback?: (err: Error | string) => void,
    ): Promise<void>;
  }

  interface ServerBase {
    /**
     * The webtorrent server is a wrapper around a http server
     */
    server: HttpServer;
    listen: HttpServer["listen"];
  }
}
