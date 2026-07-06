import { skirClient } from "../http/skir_rpc";
import {
  DeleteInventoryRule,
  DeleteInventoryRuleRequest,
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
  quantity: number;
  color_identity: string;
  rarity: string;
  card_type: string;
};

export type ProjectionLocation = {
  location_name: string;
  rule_id: string;
  total_quantity: number;
  cards: ProjectionCard[];
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
        quantity: card.quantity,
        color_identity: card.colorIdentity,
        rarity: card.rarity,
        card_type: card.cardType,
      })),
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
