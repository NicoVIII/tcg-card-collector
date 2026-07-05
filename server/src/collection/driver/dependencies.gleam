import collection/application/commands/add_cards/ports as add_cards_ports
import collection/application/commands/import_collection/ports as import_collection_ports
import collection/application/queries/latest_status/ports as latest_status_ports
import collection/application/queries/list_cards/ports as list_cards_ports

pub type Dependencies {
  Dependencies(
    import_collection_ports: import_collection_ports.ImportCollectionPorts,
    add_cards_ports: add_cards_ports.AddCardsPorts,
    latest_import_status_port: latest_status_ports.LatestImportStatusPort,
    list_collection_cards_port: list_cards_ports.ListCollectionCardsPort,
  )
}
