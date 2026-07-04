import collection/application/commands/import_collection/handler as import_collection_handler
import collection/application/commands/import_collection/ports as import_collection_ports
import collection/application/queries/latest_status/handler as latest_status_handler
import collection/application/queries/list_cards/handler as list_collection_cards_handler
import collection/application/queries/list_cards/ports as list_collection_cards_ports
import collection/domain/import_mode
import collection/driver/dependencies.{type Dependencies}
import collection/driver/skir/codec as collection_skir_codec
import gleam/list
import gleam/result
import shared/domain/non_empty_string.{type NonEmptyString}
import shared/driver/skir/skirout/collection/commands as collection_commands
import shared/driver/skir/skirout/collection/queries as collection_queries
import skir_client/service

pub fn register(
  svc: service.Service(Nil, context, Nil),
  get_dependencies: fn(context) -> Dependencies,
) -> service.Service(Nil, context, Nil) {
  svc
  |> service.add_method(
    collection_commands.import_collection_method(),
    handle_import_collection(get_dependencies),
  )
  |> service.add_method(
    collection_queries.get_latest_import_status_method(),
    handle_get_latest_import_status(get_dependencies),
  )
  |> service.add_method(
    collection_queries.list_collection_cards_method(),
    handle_list_collection_cards(get_dependencies),
  )
}

fn handle_import_collection(get_dependencies: fn(context) -> Dependencies) {
  fn(
    req: collection_commands.ImportCollectionRequest,
    req_meta: Nil,
    ctx: context,
  ) -> #(
    Result(collection_commands.ImportCollectionResponse, service.ServiceError),
    Nil,
    Nil,
  ) {
    case parse_import_request(req) {
      Ok(#(import_run_id, source_name, mode)) -> {
        let result =
          import_collection_handler.execute(
            import_collection_handler.ImportCollectionCommand(
              import_run_id: import_run_id,
              source_name: source_name,
              row_count: req.row_count,
              rows: list.map(req.rows, map_import_collection_row),
              mode: mode,
            ),
            get_dependencies(ctx).import_collection_ports,
          )
        #(
          collection_skir_codec.map_import_collection_result(result),
          req_meta,
          Nil,
        )
      }
      Error(Nil) -> #(
        Ok(collection_commands.ImportCollectionResponseRejected),
        req_meta,
        Nil,
      )
    }
  }
}

fn parse_import_request(
  req: collection_commands.ImportCollectionRequest,
) -> Result(#(NonEmptyString, NonEmptyString, import_mode.ImportMode), Nil) {
  use import_run_id <- result.try(non_empty_string.new(req.import_run_id))
  use source_name <- result.try(non_empty_string.new(req.source_name))
  use mode <- result.try(collection_skir_codec.parse_import_mode(req.mode))
  Ok(#(import_run_id, source_name, mode))
}

fn handle_get_latest_import_status(
  get_dependencies: fn(context) -> Dependencies,
) {
  fn(
    _: collection_queries.GetLatestImportStatusRequest,
    req_meta: Nil,
    ctx: context,
  ) -> #(
    Result(collection_queries.ImportStatus, service.ServiceError),
    Nil,
    Nil,
  ) {
    let result =
      latest_status_handler.execute(
        latest_status_handler.LatestImportStatusQuery,
        get_dependencies(ctx).latest_import_status_port,
      )
    #(
      collection_skir_codec.map_get_latest_import_status_result(result),
      req_meta,
      Nil,
    )
  }
}

fn map_import_collection_row(
  row: collection_commands.ImportCollectionRow,
) -> import_collection_ports.ImportCollectionRow {
  import_collection_ports.ImportCollectionRow(
    set_code: row.set_code,
    collector_number: row.collector_number,
    quantity: row.quantity,
  )
}

fn handle_list_collection_cards(get_dependencies: fn(context) -> Dependencies) {
  fn(
    req: collection_queries.ListCollectionCardsRequest,
    req_meta: Nil,
    ctx: context,
  ) -> #(
    Result(collection_queries.CollectionCardList, service.ServiceError),
    Nil,
    Nil,
  ) {
    case
      list_collection_cards_handler.execute(
        list_collection_cards_handler.ListCollectionCardsQuery(
          offset: req.offset,
          limit: req.limit,
        ),
        get_dependencies(ctx).list_collection_cards_port,
      )
    {
      Ok(page) -> {
        let response =
          collection_queries.collection_card_list_new(
            list.map(page.cards, map_collection_card),
            req.limit,
            req.offset,
            page.total,
          )
        #(Ok(response), req_meta, Nil)
      }
      Error(reason) -> #(
        Error(service.ServiceError(service.E500xInternalServerError, reason)),
        req_meta,
        Nil,
      )
    }
  }
}

fn map_collection_card(
  card: list_collection_cards_ports.CollectionCardReadModel,
) -> collection_queries.CollectionCard {
  collection_queries.collection_card_new(
    card.collector_number,
    card.quantity,
    card.set_code,
  )
}
