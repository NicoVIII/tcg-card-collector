import { mapHttpError } from "./error";

export async function requestJson<TResponse>(
  input: RequestInfo | URL,
  init?: RequestInit,
): Promise<TResponse> {
  const response = await fetch(input, init);

  if (!response.ok) {
    throw mapHttpError(response.status, "Request failed");
  }

  return (await response.json()) as TResponse;
}
