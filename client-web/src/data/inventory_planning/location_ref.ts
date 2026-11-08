// Where a copy sits, in one of two namespaces (#122): a cascade location (a
// rule target or the bulk remainder) by its rendered name, or a managed
// location by its id. A deck and a binder can share a display name, so
// anything that keys on a location keys on `locationKey`, never on a name.
export type LocationRef = { kind: "cascade" | "managed"; key: string };

export function cascadeLocation(name: string): LocationRef {
  return { kind: "cascade", key: name };
}

export function managedLocation(id: string): LocationRef {
  return { kind: "managed", key: id };
}

// A string identity for maps, sets, and the `?location=` search param. The
// kind prefix keeps the two namespaces apart.
export function locationKey(ref: LocationRef): string {
  return `${ref.kind}:${ref.key}`;
}

export function parseLocationKey(raw: string): LocationRef | null {
  const separator = raw.indexOf(":");
  const kind = raw.slice(0, separator);
  if (separator < 0 || (kind !== "cascade" && kind !== "managed")) {
    return null;
  }
  return { kind, key: raw.slice(separator + 1) };
}

type WireLocationRef =
  | { kind: "UNKNOWN"; value: undefined }
  | { kind: "cascade"; value: string }
  | { kind: "managed"; value: string };

// The server only ever sends the two known variants; an unknown one means
// client and server disagree on the contract, which must surface rather than
// file copies under a guessed location.
export function fromWireLocationRef(union: WireLocationRef): LocationRef {
  if (union.kind === "UNKNOWN") {
    throw new Error("The server sent a location of an unknown kind.");
  }
  return { kind: union.kind, key: union.value };
}

export function toWireLocationRef(ref: LocationRef): { kind: LocationRef["kind"]; value: string } {
  return { kind: ref.kind, value: ref.key };
}
