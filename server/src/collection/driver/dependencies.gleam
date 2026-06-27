import collection/application/commands/import_collection/ports as import_collection_ports
import collection/application/queries/latest_status/ports as latest_status_ports

pub type Dependencies {
  Dependencies(
    import_collection_ports: import_collection_ports.ImportCollectionPorts,
    latest_import_status_port: latest_status_ports.LatestImportStatusPort,
  )
}
