import collection/application/commands/add_cards/ports
import collection/domain/collection
import collection/domain/physical_card
import gleam/list
import gleam/result
import shared/application/command_result
import shared/domain/card_key

pub type AddCardsCommand {
  AddCardsCommand(rows: List(ports.AddCardsRow))
}

/// All-or-nothing: the client stages pre-validated entries, so a single
/// invalid row means a client bug — partial acceptance would only hide it.
/// An empty batch is invalid too; there is nothing to add.
fn validate_rows(
  rows: List(ports.AddCardsRow),
) -> Result(List(physical_card.PhysicalCard), Nil) {
  case rows {
    [] -> Error(Nil)
    _ ->
      list.try_map(rows, fn(row) {
        case
          card_key.from_user_input(
            set_code: row.set_code,
            collector_number: row.collector_number,
          ),
          physical_card.quantity_new(row.quantity)
        {
          Ok(key), Ok(quantity) ->
            Ok(physical_card.PhysicalCard(key: key, quantity: quantity))
          _, _ -> Error(Nil)
        }
      })
  }
}

fn write_model_from_card(
  card: physical_card.PhysicalCard,
) -> ports.CollectionRowWriteModel {
  ports.CollectionRowWriteModel(
    key: card.key,
    quantity: physical_card.quantity_to_int(card.quantity),
  )
}

/// Adds staged cards to the collection. The upsert sums each row's quantity
/// into the existing count per key, so merging with what is already owned is
/// the store's job — the handler only normalizes and validates the batch.
pub fn execute(
  command: AddCardsCommand,
  upsert_cards: ports.UpsertCardsPort,
) -> command_result.CommandResult(ports.AddCardsError) {
  let AddCardsCommand(rows: rows) = command

  case validate_rows(rows) {
    Error(Nil) -> Error(ports.InvalidRows)
    Ok(cards) ->
      collection.from_cards(cards)
      |> collection.to_cards
      |> list.map(write_model_from_card)
      |> upsert_cards
      |> result.map_error(ports.PersistenceFailed)
  }
}
