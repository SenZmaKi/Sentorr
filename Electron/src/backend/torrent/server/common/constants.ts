/**
 * These are errors that are recoverable i.e., are handled somewhere or they don't destroy the `client`
 */
export enum ClientRecoverableErrorMessage {
  DuplicateTorrent = "Cannot add duplicate torrent",
}

/**
 * These are errors that are recoverable i.e., are handled somewhere or they don't destroy the `client`
 */
export enum ClientRecoverableErrorCode {
  EACCES = "EACCES",
  ENOBUFS = "ENOBUFS",
}

/**
 * These are errors that are recoverable i.e., are handled somewhere or they don't destroy the `client`
 */
export enum TorrentRecoverableErrorCode {
  EPERM = "EPERM",
}

export const CLIENT_RECOVERABLE_ERROR_MESSSAGES = Object.values(
  ClientRecoverableErrorMessage,
);

export const CLIENT_RECOVERABLE_ERROR_CODES = Object.values(
  ClientRecoverableErrorCode,
);

export const TORRENT_RECOVERABLE_ERROR_CODES = Object.values(
  TorrentRecoverableErrorCode,
);
