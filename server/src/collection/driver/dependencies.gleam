import collection/application/commands/add_cards/ports as add_cards_ports
import collection/application/commands/remove_cards/ports as remove_cards_ports
import collection/application/queries/list_cards/ports as list_cards_ports

pub type Dependencies {
  Dependencies(
    add_cards_port: add_cards_ports.UpsertCardsPort,
    remove_cards_ports: remove_cards_ports.RemoveCardsPorts,
    list_collection_cards_ports: list_cards_ports.ListCollectionCardsPorts,
  )
}
