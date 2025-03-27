export function isErrorCode(error: Error | string, ...codes: string[]) {
  return (
    error instanceof Error &&
    "code" in error &&
    typeof error.code === "string" &&
    codes.includes(error.code)
  );
}
