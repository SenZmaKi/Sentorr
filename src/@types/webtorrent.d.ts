import "webtorrent";

declare module "webtorrent" {
  export interface TorrentOptions {
    deselect?: boolean;
  }

  export interface ServerBase {
    listen: HttpServer["listen"];
  }
}