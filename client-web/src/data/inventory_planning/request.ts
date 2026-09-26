import { skirClient } from "../http/skir_rpc";
import {
  fromWireFinishKind,
  fromWireLanguageKind,
  type Finish,
  type Language,
} from "../collection/copy_kind";
import {
  DeleteInventoryRule,
  DeleteInventoryRuleRequest,
  ReorderInventoryRules,
  ReorderInventoryRulesRequest,
  UpdateBulkSpec,
  UpdateBulkSpecRequest,
  UpsertInventoryRule,
  UpsertInventoryRuleRequest,
} from "../skirout/inventory_planning/commands.js";
import {
  BulkSpec as RpcBulkSpec,
  GetBulkSpec,
  GetBulkSpecRequest,
  GetInventoryProjection,
  InventoryProjection as RpcInventoryProjection,
  InventoryProjectionRequest,
  InventoryRuleList as RpcInventoryRuleList,
  ListInventoryRules,
  ListInventoryRulesRequest,
} from "../skirout/inventory_planning/queries.js";

export type InventoryRule = {
  id: string;
  location_name: string;
  expression: string;
  position: number;
  selector: string;
  sort_keys: string;
};

export type BulkSpec = {
  location_name: string;
  sort_keys: string;
};

export type InventoryRuleList = {
  data: InventoryRule[];
  total: number;
};

export type ProjectionCard = {
  name: string;
  set_code: string;
  collector_number: string;
  finish: Finish;
  language: Language;
  quantity: number;
  color_identity: string;
  rarity: string;
  card_type: string;
};

// The sort DSL's vocabulary (server domain/sort_spec.gleam), typed here so a
// section's parts don't repeat the DSL's own strings for the wire (#138).
export type SortKey =
  | "color_identity"
  | "type"
  | "name"
  | "set_code"
  | "collector_number"
  | "rarity"
  | "released_at"
  | "cmc"
  | "language";

// One sort key's category value for a section: `first === last` means every
// card in the section shares that one value; a differing pair means the part
// is a merged range ("CMC 1-3", "A-E").
export type SectionPart = {
  key: SortKey;
  first: string;
  last: string;
};

// A contiguous, divider-worthy run of a location's sorted cards. `parts` is
// empty when the location has no sort keys, or when nothing in it was worth
// dividing on; `card_count` is copies, not distinct cards.
export type ProjectionSection = {
  parts: SectionPart[];
  card_count: number;
};

export type ProjectionLocation = {
  location_name: string;
  rule_id: string;
  total_quantity: number;
  cards: ProjectionCard[];
  // Sections partition `cards` in order: walking sections and consuming
  // `card_count` copies (summing consecutive cards' `quantity`, not their
  // count) at a time lines each card up with its section.
  sections: ProjectionSection[];
};

export type InventoryProjection = {
  locations: ProjectionLocation[];
  total_quantity: number;
  unknown_count: number;
};

function toInventoryRuleList(response: RpcInventoryRuleList): InventoryRuleList {
  return {
    data: response.data.map((rule) => ({
      id: rule.id,
      location_name: rule.locationName,
      expression: rule.expression,
      position: rule.position,
      selector: rule.selector,
      sort_keys: rule.sortKeys,
    })),
    total: response.total,
  };
}

function toBulkSpec(response: RpcBulkSpec): BulkSpec {
  return {
    location_name: response.locationName,
    sort_keys: response.sortKeys,
  };
}

// A stored section's key always parses (the server only ever emits sort_spec's
// own tokens); an unrecognized kind can only mean version skew between client
// and server, so it falls back to a harmless token rather than breaking the
// whole projection — the same posture as fromWireFinishKind/LanguageKind.
function fromWireSortKeyKind(kind: string): SortKey {
  switch (kind) {
    case "COLOR_IDENTITY":
      return "color_identity";
    case "TYPE":
      return "type";
    case "SET_CODE":
      return "set_code";
    case "COLLECTOR_NUMBER":
      return "collector_number";
    case "RARITY":
      return "rarity";
    case "RELEASED_AT":
      return "released_at";
    case "CMC":
      return "cmc";
    case "LANGUAGE":
      return "language";
    default:
      return "name";
  }
}

function toProjectionSection(
  section: RpcInventoryProjection["locations"][number]["sections"][number],
): ProjectionSection {
  return {
    parts: section.parts.map((part) => ({
      key: fromWireSortKeyKind(part.key.union.kind),
      first: part.first,
      last: part.last,
    })),
    card_count: section.cardCount,
  };
}

function toInventoryProjection(response: RpcInventoryProjection): InventoryProjection {
  return {
    locations: response.locations.map((location) => ({
      location_name: location.locationName,
      rule_id: location.ruleId,
      total_quantity: location.totalQuantity,
      cards: location.cards.map((card) => ({
        name: card.name,
        set_code: card.setCode,
        collector_number: card.collectorNumber,
        finish: fromWireFinishKind(card.finish.union.kind),
        language: fromWireLanguageKind(card.language.union.kind),
        quantity: card.quantity,
        color_identity: card.colorIdentity,
        rarity: card.rarity,
        card_type: card.cardType,
      })),
      sections: location.sections.map(toProjectionSection),
    })),
    total_quantity: response.totalQuantity,
    unknown_count: response.unknownCount,
  };
}

export async function listInventoryRules(): Promise<InventoryRuleList> {
  const response = await skirClient.invokeRemote(
    ListInventoryRules,
    ListInventoryRulesRequest.create({ unit: true }),
    "POST",
  );

  return toInventoryRuleList(response);
}

export async function upsertInventoryRule(rule: InventoryRule): Promise<{ success: boolean }> {
  const response = await skirClient.invokeRemote(
    UpsertInventoryRule,
    UpsertInventoryRuleRequest.create({
      id: rule.id,
      locationName: rule.location_name,
      expression: rule.expression,
      position: rule.position,
      selector: rule.selector,
      sortKeys: rule.sort_keys,
    }),
  );

  return { success: response.union.kind === "SUCCESS" };
}

export async function deleteInventoryRule(id: string): Promise<{ success: boolean }> {
  const response = await skirClient.invokeRemote(
    DeleteInventoryRule,
    DeleteInventoryRuleRequest.create({ id }),
  );

  return { success: response.union.kind === "SUCCESS" };
}

export async function reorderInventoryRules(orderedIds: string[]): Promise<{ success: boolean }> {
  const response = await skirClient.invokeRemote(
    ReorderInventoryRules,
    ReorderInventoryRulesRequest.create({ orderedIds }),
  );

  return { success: response.union.kind === "SUCCESS" };
}

export async function getInventoryProjection(): Promise<InventoryProjection> {
  const response = await skirClient.invokeRemote(
    GetInventoryProjection,
    InventoryProjectionRequest.create({ unit: true }),
    "POST",
  );

  return toInventoryProjection(response);
}

export async function getBulkSpec(): Promise<BulkSpec> {
  const response = await skirClient.invokeRemote(
    GetBulkSpec,
    GetBulkSpecRequest.create({ unit: true }),
    "POST",
  );

  return toBulkSpec(response);
}

export async function updateBulkSpec(spec: BulkSpec): Promise<{ success: boolean }> {
  const response = await skirClient.invokeRemote(
    UpdateBulkSpec,
    UpdateBulkSpecRequest.create({
      locationName: spec.location_name,
      sortKeys: spec.sort_keys,
    }),
  );

  return { success: response.union.kind === "SUCCESS" };
}
