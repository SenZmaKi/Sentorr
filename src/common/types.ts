type Success<T> = [data: T, error: undefined];

type Failure<E> = [data: undefined, error: E];

export type Result<T, E = Error> = Success<T> | Failure<E>;

/**
 * An assertion that the if the system is ever in a specific state everything
 * should crash and burn. Mostly useful for mission critical points of failure and debugging.
 */
export class InvalidStateError extends Error {
  constructor(message: string) {
    super(`Invalid state: ${message}`);
  }
}
