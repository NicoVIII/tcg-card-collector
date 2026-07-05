import { skirClient } from "../http/skir_rpc";
import {
  CardPlacement,
  MarkCardsPlaced,
  MarkCardsPlacedRequest,
  UnmarkCardsPlaced,
  UnmarkCardsPlacedRequest,
} from "../skirout/inventory_planning/commands.js";
import {
  GetPlacementGuidance,
  PlacementGuidance as RpcPlacementGuidance,
  PlacementGuidanceRequest,
  PlacementNeighbor as RpcPlacementNeighbor,
} from "../skirout/inventory_planning/queries.js";

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

function toNeighbor(neighbor: RpcPlacementNeighbor): PlacementNeighbor {
  return {
    name: neighbor.name,
    set_code: neighbor.setCode,
    collector_number: neighbor.collectorNumber,
    already_placed: neighbor.alreadyPlaced,
  };
}

function toPlacementGuidance(response: RpcPlacementGuidance): PlacementGuidance {
  return {
    locations: response.locations.map((location) => ({
      location_name: location.locationName,
      total_quantity: location.totalQuantity,
      cards: location.cards.map((card) => ({
        name: card.name,
        set_code: card.setCode,
        collector_number: card.collectorNumber,
        to_place_quantity: card.toPlaceQuantity,
        before: card.before.map(toNeighbor),
        after: card.after.map(toNeighbor),
      })),
    })),
    total_unplaced: response.totalUnplaced,
  };
}

export async function getPlacementGuidance(): Promise<PlacementGuidance> {
  const response = await skirClient.invokeRemote(
    GetPlacementGuidance,
    PlacementGuidanceRequest.create({ unit: true }),
    "POST",
  );

  return toPlacementGuidance(response);
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
