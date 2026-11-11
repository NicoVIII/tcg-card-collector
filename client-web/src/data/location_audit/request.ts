import { skirClient } from "../http/skir_rpc";
import {
  AuditedCopy as RpcAuditedCopy,
  CompleteLocationAudit,
  CompleteLocationAuditRequest,
  UnexpectedCopy as RpcUnexpectedCopy,
} from "../skirout/inventory_planning/commands.js";
import {
  ListLocationAudits,
  ListLocationAuditsRequest,
} from "../skirout/inventory_planning/queries.js";
import { toWireFinish, toWireLanguage, type CopyIdentity } from "../collection/copy_kind";
import {
  fromWireLocationRef,
  toWireLocationRef,
  type LocationRef,
} from "../inventory_planning/location_ref";

export type AuditedCopy = CopyIdentity & { quantity: number };

// A copy found that the ledger doesn't record at the audited location. With a
// source it moves from there; without one it is marked here (ADR 0024).
export type UnexpectedCopy = { copy: AuditedCopy; source: LocationRef | null };

export type CompleteLocationAuditInput = {
  location: LocationRef;
  missing: AuditedCopy[];
  unexpected: UnexpectedCopy[];
};

// When a location was last audited, RFC 3339. Never-audited locations are
// absent from the list.
export type LocationAuditSummary = { location: LocationRef; last_audited_at: string };

function toRpcCopy(copy: AuditedCopy) {
  return RpcAuditedCopy.create({
    setCode: copy.set_code,
    collectorNumber: copy.collector_number,
    finish: toWireFinish(copy.finish),
    language: toWireLanguage(copy.language),
    quantity: copy.quantity,
  });
}

export async function completeLocationAudit(input: CompleteLocationAuditInput): Promise<void> {
  await skirClient.invokeRemote(
    CompleteLocationAudit,
    CompleteLocationAuditRequest.create({
      location: toWireLocationRef(input.location),
      missing: input.missing.map(toRpcCopy),
      unexpected: input.unexpected.map((unexpected) =>
        RpcUnexpectedCopy.create({
          copy: toRpcCopy(unexpected.copy),
          source: unexpected.source === null ? null : toWireLocationRef(unexpected.source),
        }),
      ),
    }),
  );
}

export async function listLocationAudits(): Promise<LocationAuditSummary[]> {
  const response = await skirClient.invokeRemote(
    ListLocationAudits,
    ListLocationAuditsRequest.create({ unit: true }),
    "POST",
  );

  return response.audits.map((audit) => ({
    location: fromWireLocationRef(audit.location.union),
    last_audited_at: audit.lastAuditedAt,
  }));
}
