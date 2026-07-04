import bootstrap/composition.{type Dependencies}
import catalog/driver/skir/handler as catalog_skir
import collection/driver/skir/handler as collection_skir
import gleam/erlang/process
import insights/driver/skir/handler as insights_skir
import inventory_planning/driver/skir/handler as inventory_skir
import skir_client/service

pub type RpcService =
  service.Service(Nil, Dependencies, Nil)

pub type ServerMessage {
  HandleRpc(body: String, reply: process.Subject(service.RawResponse))
}

pub type ServerName =
  process.Name(ServerMessage)

pub type ServerState {
  ServerState(service: RpcService, context: Dependencies)
}

pub fn make_service() -> RpcService {
  service.new(empty_message: Nil)
  |> catalog_skir.register(fn(ctx: Dependencies) { ctx.catalog })
  |> collection_skir.register(fn(ctx: Dependencies) { ctx.collection })
  |> inventory_skir.register(fn(ctx: Dependencies) { ctx.inventory_planning })
  |> insights_skir.register(fn(ctx: Dependencies) { ctx.insights })
}

fn handle_server_message(
  state: ServerState,
  message: ServerMessage,
) -> ServerState {
  let HandleRpc(body, reply) = message

  let #(raw, _) =
    service.handle_request(state.service, body, Nil, state.context)
  process.send(reply, raw)
  state
}

fn server_loop(
  subject: process.Subject(ServerMessage),
  state: ServerState,
) -> Nil {
  let message = process.receive_forever(subject)
  let new_state = handle_server_message(state, message)
  server_loop(subject, new_state)
}

pub fn start_server_loop(name: ServerName, initial_state: ServerState) -> Nil {
  let assert Ok(_) = process.register(process.self(), name)
  let subject = process.named_subject(name)
  server_loop(subject, initial_state)
}
