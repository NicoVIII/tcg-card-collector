import { skirClient } from "../http/skir_rpc";
import {
  CardPlacement,
  MarkCardsPlaced,
  MarkCardsPlacedRequest,
  RelocatePlacedCards,
  RelocatePlacedCardsRequest,
  UnmarkCardsPlaced,
  UnmarkCardsPlacedRequest,
} from "../skirout/inventory_planning/commands.js";
import {
  GetPlacedLedger,
  PlacedLedgerRequest,
  PlacedLedgerRow as RpcPlacedLedgerRow,
} from "../skirout/inventory_planning/queries.js";
import {
  fromWireFinishKind,
  fromWireLanguageKind,
  toWireFinish,
  toWireLanguage,
  type Finish,
  type Language,
} from "../collection/copy_kind";
import type { ProjectionSection } from "../inventory_planning/request";

// One row of the placed ledger: how many copies of a kind of copy sit in a
// location. The page folds these against the projection to derive what's
// still to place, so a placement tick only refetches this cheap read.
export type PlacedLedgerRow = {
  set_code: string;
  collector_number: string;
  finish: Finish;
  language: Language;
  location: string;
  quantity: number;
};

// The display shapes below are produced client-side by `buildGuidance`
// (data/placement/guidance.ts) from the projection + ledger; they are no
// longer a wire type.
export type PlacementNeighbor = {
  name: string;
  set_code: string;
  collector_number: string;
  // A tick names a specific kind of copy (ADR 0010); the session keys its
  // ticks the same way, so betweenLabel can recognise a neighbour ticked this
  // session as placed without waiting on the ledger refetch.
  finish: Finish;
  language: Language;
  already_placed: boolean;
};

export type PlacementCard = {
  name: string;
  set_code: string;
  collector_number: string;
  finish: Finish;
  language: Language;
  to_place_quantity: number;
  before: PlacementNeighbor[];
  after: PlacementNeighbor[];
  // The projected section this card falls in (#138) — the same object
  // reference for every card in the section, so the page can tell "still in
  // the same section as the row above" by reference rather than deep-
  // comparing parts, and a struck card keeps pointing at its section
  // regardless of ticking.
  section: ProjectionSection;
};

export type PlacementLocation = {
  location_name: string;
  total_quantity: number;
  cards: PlacementCard[];
};

export type PlacementGuidance = {
  locations: PlacementLocation[];
  total_unplaced: number;
};

// The card + destination pair a mark/unmark call operates on. The location and
// the kind of copy are both required: placement is always per-location and
// per-copy-kind, since copies of one printing can sit in more than one place
// and in more than one finish or language (ADR 0010).
export type CardPlacementInput = {
  set_code: string;
  collector_number: string;
  finish: Finish;
  language: Language;
  location_name: string;
  quantity: number;
};

function toLedgerRow(row: RpcPlacedLedgerRow): PlacedLedgerRow {
  return {
    set_code: row.setCode,
    collector_number: row.collectorNumber,
    finish: fromWireFinishKind(row.finish.union.kind),
    language: fromWireLanguageKind(row.language.union.kind),
    location: row.location,
    quantity: row.quantity,
  };
}

export async function getPlacedLedger(): Promise<PlacedLedgerRow[]> {
  const response = await skirClient.invokeRemote(
    GetPlacedLedger,
    PlacedLedgerRequest.create({ unit: true }),
    "POST",
  );

  return response.rows.map(toLedgerRow);
}

function toRpcPlacements(placements: CardPlacementInput[]) {
  return placements.map((placement) =>
    CardPlacement.create({
      setCode: placement.set_code,
      collectorNumber: placement.collector_number,
      finish: toWireFinish(placement.finish),
      language: toWireLanguage(placement.language),
      locationName: placement.location_name,
      quantity: placement.quantity,
    }),
  );
}

export async function markCardsPlaced(
  placements: CardPlacementInput[],
): Promise<{ success: boolean }> {
  const response = await skirClient.invokeRemote(
    MarkCardsPlaced,
    MarkCardsPlacedRequest.create({ placements: toRpcPlacements(placements) }),
  );

  return { success: response.union.kind === "SUCCESS" };
}

export async function unmarkCardsPlaced(
  placements: CardPlacementInput[],
): Promise<{ success: boolean }> {
  const response = await skirClient.invokeRemote(
    UnmarkCardsPlaced,
    UnmarkCardsPlacedRequest.create({ placements: toRpcPlacements(placements) }),
  );

  return { success: response.union.kind === "SUCCESS" };
}

// Re-points every ledger row at `from_location_name` onto `to_location_name`
// — the "it's the same box, just renamed" resolution for a re-sort group
// (data/placement/resort.ts). No CopyKey involved: this is a bookkeeping fix,
// not a record of cards physically moving.
export async function relocatePlacedCards(
  from_location_name: string,
  to_location_name: string,
): Promise<{ success: boolean }> {
  const response = await skirClient.invokeRemote(
    RelocatePlacedCards,
    RelocatePlacedCardsRequest.create({
      fromLocationName: from_location_name,
      toLocationName: to_location_name,
    }),
  );

  return { success: response.union.kind === "SUCCESS" };
}
