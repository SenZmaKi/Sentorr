type Success<T> = [data: T, error: undefined];

type Failure<E> = [data: undefined, error: E];

export type Result<T, E = Error> = Success<T> | Failure<E>;

/**
 * An assertion that the if the system is ever in a specific state everything
 * should crash and burn. Ideally this should never be thrown, mostly useful for debugging.
 */
export class InvalidStateError extends Error {
  constructor(message: string) {
    super(`Invalid state: ${message}`);
  }
}
