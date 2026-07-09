import { skirClient } from "../http/skir_rpc";
import {
  CardPlacement,
  MarkCardsPlaced,
  MarkCardsPlacedRequest,
  UnmarkCardsPlaced,
  UnmarkCardsPlacedRequest,
} from "../skirout/inventory_planning/commands.js";
import {
  GetPlacedLedger,
  PlacedLedgerRequest,
  PlacedLedgerRow as RpcPlacedLedgerRow,
} from "../skirout/inventory_planning/queries.js";

// One row of the placed ledger: how many copies of a key sit in a location.
// The page folds these against the projection to derive what's still to place,
// so a placement tick only refetches this cheap read.
export type PlacedLedgerRow = {
  set_code: string;
  collector_number: string;
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
  already_placed: boolean;
};

export type PlacementCard = {
  name: string;
  set_code: string;
  collector_number: string;
  to_place_quantity: number;
  before: PlacementNeighbor[];
  after: PlacementNeighbor[];
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

// The card + destination pair a mark/unmark call operates on. The location is
// required: placement is always per-location, since a copy of one key can sit
// in more than one place.
export type CardPlacementInput = {
  set_code: string;
  collector_number: string;
  location_name: string;
  quantity: number;
};

function toLedgerRow(row: RpcPlacedLedgerRow): PlacedLedgerRow {
  return {
    set_code: row.setCode,
    collector_number: row.collectorNumber,
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
