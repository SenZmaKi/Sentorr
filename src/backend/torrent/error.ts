export class TimeoutError extends Error {
    constructor() {
        super("Timeout, torrent is probably dead");
    }
}