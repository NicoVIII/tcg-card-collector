import skir_client/service

/// What `service.add_method` expects from every handler in this codebase: the
/// services carry no request metadata and emit no messages, so both extra
/// slots are `Nil`.
pub type MethodHandler(req, resp, context) =
  fn(req, Nil, context) -> #(Result(resp, service.ServiceError), Nil, Nil)
