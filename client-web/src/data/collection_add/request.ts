import { z } from "zod";
import { skirClient } from "../http/skir_rpc";
import { AddCards, AddCardsRequest } from "../skirout/collection/commands.js";

const AddCardsResponseSchema = z.object({
  union: z.object({ kind: z.enum(["ADDED", "REJECTED", "UNKNOWN"]) }),
});

export type AddCardsPayload = {
  addRunId: string;
  rows: Array<{
    setCode: string;
    collectorNumber: string;
    quantity: number;
  }>;
};

export async function postAddCards(payload: AddCardsPayload): Promise<{ added: boolean }> {
  const response = await skirClient.invokeRemote(
    AddCards,
    AddCardsRequest.create({
      addRunId: payload.addRunId,
      rows: payload.rows,
    }),
  );

  const validated = AddCardsResponseSchema.parse(response);
  return { added: validated.union.kind === "ADDED" };
}
