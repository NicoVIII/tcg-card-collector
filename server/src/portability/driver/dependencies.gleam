import portability/application/commands/import_data/ports as import_data_ports
import portability/application/queries/export_data/ports as export_data_ports
import portability/application/queries/preview_import/ports as preview_import_ports

pub type Dependencies {
  Dependencies(
    export_data_ports: export_data_ports.ExportDataPorts,
    import_data_ports: import_data_ports.ImportDataPorts,
    preview_import_ports: preview_import_ports.PreviewImportPorts,
  )
}
