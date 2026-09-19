import collection/application/commands/import_collection/ports
import collection/domain/collection
import collection/domain/physical_card
import gleam/list
import gleam/result
import shared/application/command_result
import shared/domain/copy_key

pub type ImportCollectionCommand {
  ImportCollectionCommand(rows: List(ports.ImportCollectionRow))
}

/// All-or-nothing, like AddCards: an import states the whole collection, so a
/// single invalid row (or an empty batch) rejects the request rather than
/// silently importing a partial collection.
fn validate_rows(
  rows: List(ports.ImportCollectionRow),
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

/// An import replaces the whole collection with the sent rows; incremental
/// additions go through the add_cards command instead. A successful replace
/// notifies any subscriber that owned quantities may have shrunk (ADR 0011);
/// the notification's own result is ignored on purpose — a reconciliation
/// failure must not fail an import that already committed its own write.
pub fn execute(
  command: ImportCollectionCommand,
  ports: ports.ImportCollectionPorts,
) -> command_result.CommandResult(ports.ImportCollectionError) {
  let ImportCollectionCommand(rows: rows) = command

  case validate_rows(rows) {
    Error(Nil) -> Error(ports.InvalidRows)
    Ok(cards) -> {
      let write_models =
        collection.from_cards(cards)
        |> collection.to_cards
        |> list.map(write_model_from_card)

      use _ <- result.try(
        ports.replace_collection(write_models)
        |> result.map_error(ports.PersistenceFailed),
      )
      // nolint: discarded_result -- ADR 0011: a reconciliation failure must not fail this command; the subscriber logs its own failures
      let _ = ports.notify_changed(Nil)
      Ok(Nil)
    }
  }
}
