/**
 * Generate a RFC 4122 v4 UUID.
 *
 * `crypto.randomUUID` is only defined in secure contexts (HTTPS or localhost).
 * A self-hosted instance is commonly reached over plain HTTP on a LAN IP, where
 * it is `undefined`. `crypto.getRandomValues` has no secure-context requirement,
 * so we fall back to building the UUID ourselves from it.
 */
export function randomUUID(): string {
  if (typeof crypto.randomUUID === "function") {
    return crypto.randomUUID();
  }

  const bytes = crypto.getRandomValues(new Uint8Array(16));
  // Set version (4) and variant (10xx) bits per RFC 4122.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;

  const hex: string[] = [];
  for (let i = 0; i < 256; i++) {
    hex.push((i + 0x100).toString(16).slice(1));
  }

  return (
    hex[bytes[0]] +
    hex[bytes[1]] +
    hex[bytes[2]] +
    hex[bytes[3]] +
    "-" +
    hex[bytes[4]] +
    hex[bytes[5]] +
    "-" +
    hex[bytes[6]] +
    hex[bytes[7]] +
    "-" +
    hex[bytes[8]] +
    hex[bytes[9]] +
    "-" +
    hex[bytes[10]] +
    hex[bytes[11]] +
    hex[bytes[12]] +
    hex[bytes[13]] +
    hex[bytes[14]] +
    hex[bytes[15]]
  );
}
