import { z } from "zod";
import { skirClient } from "../http/skir_rpc";
import { AddCards, AddCardsRequest } from "../skirout/collection/commands.js";
import { toWireFinish, toWireLanguage, type Finish, type Language } from "../collection/copy_kind";

const AddCardsResponseSchema = z.object({
  union: z.object({ kind: z.enum(["ADDED", "REJECTED", "UNKNOWN"]) }),
});

export type AddCardsPayload = {
  rows: Array<{
    setCode: string;
    collectorNumber: string;
    finish: Finish;
    language: Language;
    quantity: number;
  }>;
};

export async function postAddCards(payload: AddCardsPayload): Promise<{ added: boolean }> {
  const response = await skirClient.invokeRemote(
    AddCards,
    AddCardsRequest.create({
      rows: payload.rows.map((row) => ({
        ...row,
        finish: toWireFinish(row.finish),
        language: toWireLanguage(row.language),
      })),
    }),
  );

  const validated = AddCardsResponseSchema.parse(response);
  return { added: validated.union.kind === "ADDED" };
}
