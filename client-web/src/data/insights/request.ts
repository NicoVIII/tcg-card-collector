import { z } from "zod";
import { skirClient } from "../http/skir_rpc";
import {
  MarkTargetSet,
  MarkTargetSetRequest,
  UnmarkTargetSet,
  UnmarkTargetSetRequest,
} from "../skirout/insights/commands.js";
import { GetSetCompletion, GetSetCompletionRequest } from "../skirout/insights/queries.js";

const SetCompletionListSchema = z.object({
  data: z.array(
    z.object({
      setCode: z.string(),
      owned: z.number(),
      total: z.number().nullable(),
    }),
  ),
});

export type SetCompletion = {
  set_code: string;
  owned: number;
  // null when the set has no official size; the UI shows owned without a denominator.
  total: number | null;
};

export async function getSetCompletion(): Promise<SetCompletion[]> {
  const response = await skirClient.invokeRemote(
    GetSetCompletion,
    GetSetCompletionRequest.create({ unit: true }),
    "POST",
  );

  const validated = SetCompletionListSchema.parse(response);
  return validated.data.map((row) => ({
    set_code: row.setCode,
    owned: row.owned,
    total: row.total,
  }));
}

export async function markTargetSet(setCode: string): Promise<{ success: boolean }> {
  const response = await skirClient.invokeRemote(
    MarkTargetSet,
    MarkTargetSetRequest.create({ setCode }),
  );

  return { success: response.union.kind === "SUCCESS" };
}

export async function unmarkTargetSet(setCode: string): Promise<{ success: boolean }> {
  const response = await skirClient.invokeRemote(
    UnmarkTargetSet,
    UnmarkTargetSetRequest.create({ setCode }),
  );

  return { success: response.union.kind === "SUCCESS" };
}
