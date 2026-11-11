import { describe, expect, it } from "vitest";
import type { CopyIdentity } from "../collection/copy_kind";
import { cascadeLocation, managedLocation } from "../inventory_planning/location_ref";
import type { PlacedLedgerRow } from "../placement/request";
import type { AuditRow } from "./audit_list";
import {
  addUnexpected,
  emptyAuditSession,
  reportOnly,
  restoreSession,
  serializeSession,
  setFound,
  toRequest,
  unresolvedCopies,
} from "./audit_session";

const binder = cascadeLocation("Binder");
const deck = managedLocation("d1");

function copy(collector_number: string): CopyIdentity {
  return { set_code: "m11", collector_number, finish: "nonfoil", language: "en" };
}

function row(collector_number: string, recorded: number): AuditRow {
  return { ...copy(collector_number), name: "", recorded };
}

function placed(collector_number: string, location = binder, quantity = 1): PlacedLedgerRow {
  return { ...copy(collector_number), location, quantity };
}

describe("toRequest", () => {
  it("sends what wasn't found as missing and in-collection finds as unexpected", () => {
    const rows = [row("1", 2), row("2", 1)];
    let session = setFound(emptyAuditSession(), rows[0], 1);
    session = setFound(session, rows[1], 1);
    session = addUnexpected(session, {
      copy: copy("3"),
      quantity: 1,
      in_collection: true,
      source: deck,
    });
    session = addUnexpected(session, {
      copy: copy("4"),
      quantity: 1,
      in_collection: false,
      source: null,
    });

    expect(toRequest(binder, session, rows)).toEqual({
      location: binder,
      missing: [{ ...copy("1"), quantity: 1 }],
      unexpected: [{ copy: { ...copy("3"), quantity: 1 }, source: deck }],
    });
    expect(reportOnly(session).map((find) => find.copy.collector_number)).toEqual(["4"]);
  });

  it("treats an untouched row as entirely missing", () => {
    expect(toRequest(binder, emptyAuditSession(), [row("1", 2)]).missing).toEqual([
      { ...copy("1"), quantity: 2 },
    ]);
  });
});

describe("setFound", () => {
  it("rejects a count beyond what the ledger records", () => {
    expect(() => setFound(emptyAuditSession(), row("1", 2), 3)).toThrow(RangeError);
  });
});

describe("unresolvedCopies", () => {
  const owned = new Map([["m11 1 nonfoil en", 1]]);

  it("flags an unsourced find when every owned copy is already placed", () => {
    const session = addUnexpected(emptyAuditSession(), {
      copy: copy("1"),
      quantity: 1,
      in_collection: true,
      source: null,
    });

    expect(unresolvedCopies(session, owned, [placed("1", deck)])).toEqual(
      new Set(["m11 1 nonfoil en"]),
    );
    expect(unresolvedCopies(session, owned, [])).toEqual(new Set());
  });

  it("clears once the find names a source recording enough copies", () => {
    const session = addUnexpected(emptyAuditSession(), {
      copy: copy("1"),
      quantity: 1,
      in_collection: true,
      source: deck,
    });

    expect(unresolvedCopies(session, owned, [placed("1", deck)])).toEqual(new Set());
    expect(unresolvedCopies(session, owned, [placed("1", cascadeLocation("Box"))])).toEqual(
      new Set(["m11 1 nonfoil en"]),
    );
  });
});

describe("restoreSession", () => {
  it("restores a saved walk that still fits the ledger", () => {
    const rows = [row("1", 2)];
    const saved = serializeSession(setFound(emptyAuditSession(), rows[0], 2));

    const outcome = restoreSession(saved, rows);
    expect(outcome.kind).toBe("restored");
  });

  it("drops a walk whose counts the ledger no longer covers", () => {
    const saved = serializeSession(setFound(emptyAuditSession(), row("1", 2), 2));

    expect(restoreSession(saved, [row("1", 1)])).toEqual({ kind: "stale" });
  });

  it("reports unreadable storage instead of guessing", () => {
    expect(restoreSession("{not json", [])).toEqual({ kind: "unreadable" });
    expect(restoreSession("{}", [])).toEqual({ kind: "unreadable" });
  });
});
