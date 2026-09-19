import { z } from "zod";
import { skirClient } from "../http/skir_rpc";
import { RemoveCards, RemoveCardsRequest } from "../skirout/collection/commands.js";
import { toWireFinish, toWireLanguage, type Finish, type Language } from "../collection/copy_kind";

const RemoveCardsResponseSchema = z.object({
  union: z.object({ kind: z.enum(["DECREMENTED", "REJECTED", "UNKNOWN"]) }),
});

export type RemoveCardsPayload = {
  rows: Array<{
    setCode: string;
    collectorNumber: string;
    finish: Finish;
    language: Language;
    quantity: number;
  }>;
};

export async function postRemoveCards(
  payload: RemoveCardsPayload,
): Promise<{ decremented: boolean }> {
  const response = await skirClient.invokeRemote(
    RemoveCards,
    RemoveCardsRequest.create({
      rows: payload.rows.map((row) => ({
        ...row,
        finish: toWireFinish(row.finish),
        language: toWireLanguage(row.language),
      })),
    }),
  );

  const validated = RemoveCardsResponseSchema.parse(response);
  return { decremented: validated.union.kind === "DECREMENTED" };
}
