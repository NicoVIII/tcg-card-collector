export type AppError = {
  message: string;
  status?: number;
};

// skir-client's invokeRemote throws plain Errors shaped "HTTP status <code>[: <text>]".
// This is the only place that format may be parsed.
export function httpStatusFromError(error: unknown): number | undefined {
  if (error instanceof Error) {
    const match = /^HTTP status (\d{3})/.exec(error.message);
    if (match !== null) {
      return Number(match[1]);
    }
  }
  return undefined;
}

export function mapError(error: unknown): AppError {
  if (error instanceof Error) {
    return { message: error.message, status: httpStatusFromError(error) };
  }

  return { message: "Unknown application error" };
}
