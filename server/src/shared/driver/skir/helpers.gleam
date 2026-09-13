import shared/driver/presented_error.{type PresentedError, BadRequest, Internal}
import skir_client/service

/// What `service.add_method` expects from every handler in this codebase: the
/// services carry no request metadata and emit no messages, so both extra
/// slots are `Nil`.
pub type MethodHandler(req, resp, context) =
  fn(req, Nil, context) -> #(Result(resp, service.ServiceError), Nil, Nil)

/// Wraps a codec result into the tuple `MethodHandler` returns.
pub fn respond(
  result: Result(resp, service.ServiceError),
) -> #(Result(resp, service.ServiceError), Nil, Nil) {
  #(result, Nil, Nil)
}

/// Query ports fail with a bare reason, which always surfaces as a 500.
pub fn map_query(
  result: Result(a, String),
  encode: fn(a) -> resp,
) -> Result(resp, service.ServiceError) {
  case result {
    Ok(value) -> Ok(encode(value))
    Error(reason) ->
      Error(service.ServiceError(service.E500xInternalServerError, reason))
  }
}

pub fn service_error(error: PresentedError) -> service.ServiceError {
  let code = case error.class {
    BadRequest -> service.E400xBadRequest
    Internal -> service.E500xInternalServerError
  }
  service.ServiceError(code, error.message)
}

/// Commands succeed with a fixed response variant; failures go through the
/// use case's error presentation.
pub fn map_command(
  result: Result(Nil, e),
  success: resp,
  present: fn(e) -> PresentedError,
) -> Result(resp, service.ServiceError) {
  case result {
    Ok(Nil) -> Ok(success)
    Error(error) -> Error(service_error(present(error)))
  }
}
