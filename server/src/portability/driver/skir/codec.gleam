import portability/domain/export_document.{type ExportDocument}
import portability/driver/export_file
import shared/driver/skir/skirout/portability/queries as portability_queries

pub fn map_export_data(
  document: ExportDocument,
) -> portability_queries.ExportFile {
  portability_queries.export_file_new(
    content: export_file.render(document),
    filename: export_file.filename(document),
  )
}
