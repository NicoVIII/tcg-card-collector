export type AppError = {
  message: string;
  status?: number;
};

export function mapError(error: unknown): AppError {
  if (error instanceof Error) {
    return { message: error.message };
  }

  return { message: "Unknown application error" };
}

export function mapHttpError(status: number, fallback: string): AppError {
  return {
    message: `${fallback} (status ${status})`,
    status,
  };
}
