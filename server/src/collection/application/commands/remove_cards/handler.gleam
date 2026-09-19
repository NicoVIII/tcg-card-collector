import collection/application/commands/remove_cards/ports
import collection/domain/collection
import collection/domain/physical_card
import gleam/list
import gleam/result
import shared/application/command_result
import shared/domain/copy_key

pub type RemoveCardsCommand {
  RemoveCardsCommand(rows: List(ports.RemoveCardsRow))
}

/// All-or-nothing, like AddCards: the client stages pre-validated entries, so
/// a single invalid row means a client bug. An empty batch is invalid too;
/// there is nothing to remove.
fn validate_rows(
  rows: List(ports.RemoveCardsRow),
) -> Result(List(physical_card.PhysicalCard), Nil) {
  case rows {
    [] -> Error(Nil)
    _ ->
      list.try_map(rows, fn(row) {
        case
          copy_key.from_user_input(
            set_code: row.set_code,
            collector_number: row.collector_number,
            finish: row.finish,
            language: row.language,
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

/// Removes staged cards from the collection. The decrement floors each key
/// at zero and prunes the row entirely rather than erroring on an
/// over-removal — mirrors AddCards' upsert, whose merge-on-write is the
/// store's job too. A successful decrement notifies any subscriber that
/// owned quantities may have shrunk; the notification's own result is
/// ignored on purpose (ADR 0011: a reconciliation failure must not fail a
/// removal that already committed its own write).
pub fn execute(
  command: RemoveCardsCommand,
  ports: ports.RemoveCardsPorts,
) -> command_result.CommandResult(ports.RemoveCardsError) {
  let RemoveCardsCommand(rows: rows) = command

  case validate_rows(rows) {
    Error(Nil) -> Error(ports.InvalidRows)
    Ok(cards) -> {
      let write_models =
        collection.from_cards(cards)
        |> collection.to_cards
        |> list.map(write_model_from_card)

      use _ <- result.try(
        ports.decrement_cards(write_models)
        |> result.map_error(ports.PersistenceFailed),
      )
      // nolint: discarded_result -- ADR 0011: a reconciliation failure must not fail this command; the subscriber logs its own failures
      let _ = ports.notify_changed(Nil)
      Ok(Nil)
    }
  }
}
