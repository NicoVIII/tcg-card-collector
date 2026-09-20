import { z } from "zod";
import { skirClient } from "../http/skir_rpc";
import { GetAppVersion, GetAppVersionRequest } from "../skirout/system/queries.js";

const AppVersionSchema = z.object({
  version: z.string(),
});

export async function getAppVersion(): Promise<string> {
  const response = await skirClient.invokeRemote(
    GetAppVersion,
    GetAppVersionRequest.create({ unit: true }),
    "POST",
  );

  return AppVersionSchema.parse(response).version;
}
