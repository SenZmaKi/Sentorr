
export function isErrorCode(error: Error | string, code: string) {
    return error instanceof Error && "code" in error && error.code === code;
}
