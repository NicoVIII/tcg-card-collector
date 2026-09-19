import collection/application/commands/add_cards/handler as add_cards_handler
import collection/application/commands/import_collection/handler as import_collection_handler
import collection/application/commands/remove_cards/handler as remove_cards_handler
import collection/application/queries/list_cards/handler as list_collection_cards_handler
import collection/driver/dependencies.{type Dependencies}
import collection/driver/skir/codec as collection_skir_codec
import gleam/list
import shared/driver/skir/helpers
import shared/driver/skir/skirout/collection/commands as collection_commands
import shared/driver/skir/skirout/collection/queries as collection_queries
import skir_client/service

fn handle_import_collection(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  collection_commands.ImportCollectionRequest,
  collection_commands.ImportCollectionResponse,
  context,
) {
  fn(req: collection_commands.ImportCollectionRequest, _, ctx) {
    import_collection_handler.execute(
      import_collection_handler.ImportCollectionCommand(rows: list.map(
        req.rows,
        collection_skir_codec.to_import_collection_row,
      )),
      get_dependencies(ctx).import_collection_port,
    )
    |> collection_skir_codec.map_import_collection_result
    |> helpers.respond
  }
}

fn handle_add_cards(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  collection_commands.AddCardsRequest,
  collection_commands.AddCardsResponse,
  context,
) {
  fn(req: collection_commands.AddCardsRequest, _, ctx) {
    add_cards_handler.execute(
      add_cards_handler.AddCardsCommand(rows: list.map(
        req.rows,
        collection_skir_codec.to_add_cards_row,
      )),
      get_dependencies(ctx).add_cards_port,
    )
    |> collection_skir_codec.map_add_cards_result
    |> helpers.respond
  }
}

fn handle_remove_cards(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  collection_commands.RemoveCardsRequest,
  collection_commands.RemoveCardsResponse,
  context,
) {
  fn(req: collection_commands.RemoveCardsRequest, _, ctx) {
    remove_cards_handler.execute(
      remove_cards_handler.RemoveCardsCommand(rows: list.map(
        req.rows,
        collection_skir_codec.to_remove_cards_row,
      )),
      get_dependencies(ctx).remove_cards_ports,
    )
    |> collection_skir_codec.map_remove_cards_result
    |> helpers.respond
  }
}

fn handle_list_collection_cards(
  get_dependencies: fn(context) -> Dependencies,
) -> helpers.MethodHandler(
  collection_queries.ListCollectionCardsRequest,
  collection_queries.CollectionCardList,
  context,
) {
  fn(req: collection_queries.ListCollectionCardsRequest, _, ctx) {
    list_collection_cards_handler.execute(
      list_collection_cards_handler.ListCollectionCardsQuery(
        offset: req.offset,
        limit: req.limit,
      ),
      get_dependencies(ctx).list_collection_cards_port,
    )
    |> helpers.map_query(collection_skir_codec.map_collection_card_page(
      _,
      req.offset,
      req.limit,
    ))
    |> helpers.respond
  }
}

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
    collection_commands.add_cards_method(),
    handle_add_cards(get_dependencies),
  )
  |> service.add_method(
    collection_commands.remove_cards_method(),
    handle_remove_cards(get_dependencies),
  )
  |> service.add_method(
    collection_queries.list_collection_cards_method(),
    handle_list_collection_cards(get_dependencies),
  )
}
