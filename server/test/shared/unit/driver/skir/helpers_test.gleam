import shared/driver/presented_error.{BadRequest, Internal, PresentedError}
import shared/driver/skir/helpers
import skir_client/service

pub fn map_query_encodes_the_success_value_test() {
  assert helpers.map_query(Ok(2), fn(n) { n * 10 }) == Ok(20)
}

pub fn map_query_turns_a_failure_into_an_internal_server_error_test() {
  assert helpers.map_query(Error("db locked"), fn(n: Int) { n })
    == Error(service.ServiceError(service.E500xInternalServerError, "db locked"))
}

pub fn service_error_maps_classes_to_skir_codes_test() {
  assert helpers.service_error(PresentedError(BadRequest, "bad"))
    == service.ServiceError(service.E400xBadRequest, "bad")
  assert helpers.service_error(PresentedError(Internal, "boom"))
    == service.ServiceError(service.E500xInternalServerError, "boom")
}

pub fn map_command_returns_the_success_variant_test() {
  assert helpers.map_command(Ok(Nil), "done", fn(_: Nil) {
      PresentedError(Internal, "unused")
    })
    == Ok("done")
}

pub fn map_command_presents_the_failure_test() {
  assert helpers.map_command(Error("invalid"), "done", fn(_) {
      PresentedError(BadRequest, "invalid input")
    })
    == Error(service.ServiceError(service.E400xBadRequest, "invalid input"))
}
