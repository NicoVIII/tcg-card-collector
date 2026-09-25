import portability/application/queries/export_data/ports as export_data_ports

pub type Dependencies {
  Dependencies(export_data_ports: export_data_ports.ExportDataPorts)
}
