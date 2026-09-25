import { skirClient } from "../http/skir_rpc";
import { ExportData, ExportDataRequest } from "../skirout/portability/queries.js";

export type ExportFile = {
  filename: string;
  content: string;
};

export async function fetchExportData(): Promise<ExportFile> {
  const response = await skirClient.invokeRemote(
    ExportData,
    ExportDataRequest.create({ unit: true }),
    "POST",
  );

  return { filename: response.filename, content: response.content };
}
