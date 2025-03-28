/**
 * These are errors that are recoverable i.e., are handled somewhere or they don't destroy the `client`
 */
export enum RecoverableErrorMessage {
  DuplicateTorrent = "Cannot add duplicate torrent",
}

/**
 * These are errors that are recoverable i.e., are handled somewhere or they don't destroy the `client`
 */
export enum RecoverableErrorCode {
  EACCES = "EACCES",
  ENOBUFS = "ENOBUFS",
}

export const RECOVERABLE_ERROR_MESSSAGES = Object.values(
  RecoverableErrorMessage,
);
export const RECOVERABLE_ERROR_CODES = Object.values(RecoverableErrorCode);
