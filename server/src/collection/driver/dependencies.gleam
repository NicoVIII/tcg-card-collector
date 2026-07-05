import collection/application/commands/add_cards/ports as add_cards_ports
import collection/application/commands/import_collection/ports as import_collection_ports
import collection/application/queries/list_cards/ports as list_cards_ports

pub type Dependencies {
  Dependencies(
    import_collection_port: import_collection_ports.ReplaceCollectionPort,
    add_cards_port: add_cards_ports.UpsertCardsPort,
    list_collection_cards_port: list_cards_ports.ListCollectionCardsPort,
  )
}
