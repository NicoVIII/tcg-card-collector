import { requestJson } from "../http/request";

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

export async function listInventoryRules(): Promise<InventoryRuleList> {
  return requestJson<InventoryRuleList>("/api/inventory/rules");
}

export async function upsertInventoryRule(rule: InventoryRule): Promise<{ success: boolean }> {
  return requestJson<{ success: boolean }>("/api/inventory/rules", {
    method: "PUT",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(rule),
  });
}

export async function deleteInventoryRule(id: string): Promise<{ success: boolean }> {
  return requestJson<{ success: boolean }>("/api/inventory/rules", {
    method: "DELETE",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ id }),
  });
}

export async function getInventoryProjection(
  sortBy: string,
  groupBy: string,
): Promise<InventoryProjection> {
  return requestJson<InventoryProjection>(
    `/api/inventory/projection?sort_by=${sortBy}&group_by=${groupBy}`,
  );
}
