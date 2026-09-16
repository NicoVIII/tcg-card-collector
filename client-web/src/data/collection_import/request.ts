import { z } from "zod";
import { skirClient } from "../http/skir_rpc";
import { ImportCollection, ImportCollectionRequest } from "../skirout/collection/commands.js";
import { toWireFinish, toWireLanguage, type Finish, type Language } from "../collection/copy_kind";

const ImportCollectionResponseSchema = z.object({
  union: z.object({ kind: z.enum(["ACCEPTED", "REJECTED", "UNKNOWN"]) }),
});

export type ImportCollectionPayload = {
  rows: Array<{
    setCode: string;
    collectorNumber: string;
    finish: Finish;
    language: Language;
    quantity: number;
  }>;
};

export async function postImportCollection(
  payload: ImportCollectionPayload,
): Promise<{ accepted: boolean }> {
  const response = await skirClient.invokeRemote(
    ImportCollection,
    ImportCollectionRequest.create({
      rows: payload.rows.map((row) => ({
        ...row,
        finish: toWireFinish(row.finish),
        language: toWireLanguage(row.language),
      })),
    }),
  );

  const validated = ImportCollectionResponseSchema.parse(response);
  return { accepted: validated.union.kind === "ACCEPTED" };
}
