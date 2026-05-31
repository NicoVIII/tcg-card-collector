import { ServiceClient } from "skir-client";

function rpcBaseUrl(): string {
  if (typeof window !== "undefined" && window.location.origin !== "null") {
    return new URL("/api/skir", window.location.origin).toString();
  }

  return "http://localhost/api/skir";
}

export const skirClient = new ServiceClient(rpcBaseUrl());
