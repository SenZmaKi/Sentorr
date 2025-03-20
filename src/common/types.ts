
export class InvalidStateError extends Error {
  constructor(message: string) {
    super(`Invalid state: ${message}`);
  }
}
