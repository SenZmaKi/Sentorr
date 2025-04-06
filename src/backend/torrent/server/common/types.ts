import type torrentServer from "../server";

export enum GetTorrentStreamError {
  TorrentTimeout = "Torrent timeout",
  NoMatchingFile = "No matching file",
}

export enum SelectTorrentStreamError {
  StreamNotFound = "Torrent stream not found",
}

export enum TorrentClientError {
  ClientIsDestroyed = "Client is destroyed",
}

/**
 * Zero typically means use default value or infinite
 */
export type TorrentServerConfig = {
  maxConns: number;
  torrentPort: number;
  serverPort: number;
  maxTorrentStreams: number;
  torrentTimeoutSecs: number;
  torrentTimeoutRetries: number;
};

export type TorrentStreamStats = {
  downloadSpeed: number;
  uploadSpeed: number;
  numPeers: number;
};
export type TorrentStream = {
  filepath: string;
  filename: string;
  magnetURI: string;
  url: string;
};

export type TorrentServer = typeof torrentServer;
