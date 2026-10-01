export function hasErrorCode(error: Error | string, codes: string[]) {
  return (
    error instanceof Error &&
    "code" in error &&
    typeof error.code === "string" &&
    codes.includes(error.code)
  );
}

export function hasErrorMessage(error: Error | string, messages: string[]) {
  const message = error instanceof Error ? error.message : error;
  return messages.some((m) => message.includes(m));
}
