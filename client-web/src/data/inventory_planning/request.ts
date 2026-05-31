import { skirClient } from "../http/skir_rpc";
import {
  DeleteInventoryRule,
  DeleteInventoryRuleRequest,
  UpsertInventoryRule,
  UpsertInventoryRuleRequest,
} from "../skirout/inventory_planning/commands.js";
import {
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
};

export type InventoryRuleList = {
  data: InventoryRule[];
  total: number;
};

export type InventoryProjectionRow = {
  location_name: string;
  card_name: string;
  set_code: string;
  quantity: number;
  group_value: string;
};

export type InventoryProjection = {
  data: InventoryProjectionRow[];
  total: number;
};

function toInventoryRuleList(response: RpcInventoryRuleList): InventoryRuleList {
  return {
    data: response.data.map((rule) => ({
      id: rule.id,
      location_name: rule.locationName,
      expression: rule.expression,
    })),
    total: response.total,
  };
}

function toInventoryProjection(response: RpcInventoryProjection): InventoryProjection {
  return {
    data: response.data.map((row) => ({
      location_name: row.locationName,
      card_name: row.cardName,
      set_code: row.setCode,
      quantity: row.quantity,
      group_value: row.groupValue,
    })),
    total: response.total,
  };
}

export async function listInventoryRules(): Promise<InventoryRuleList> {
  const response = await skirClient.invokeRemote(
    ListInventoryRules,
    ListInventoryRulesRequest.create({ unit: true }),
    "GET",
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

export async function getInventoryProjection(
  sortBy: string,
  groupBy: string,
): Promise<InventoryProjection> {
  const response = await skirClient.invokeRemote(
    GetInventoryProjection,
    InventoryProjectionRequest.create({ sortBy, groupBy }),
    "GET",
  );

  return toInventoryProjection(response);
}
