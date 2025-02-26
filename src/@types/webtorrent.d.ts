/// <reference types="webtorrent" />

import "webtorrent";
module "webtorrent" {
  interface TorrentOptions {
    deselect?: boolean;
  }

  interface ServerBase {
    listen: (...args) => unknown;
  }
}
