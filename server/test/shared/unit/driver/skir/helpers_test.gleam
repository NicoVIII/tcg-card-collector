import shared/driver/skir/helpers
import skir_client/service

pub fn map_query_encodes_the_success_value_test() {
  assert helpers.map_query(Ok(2), fn(n) { n * 10 }) == Ok(20)
}

pub fn map_query_turns_a_failure_into_an_internal_server_error_test() {
  assert helpers.map_query(Error("db locked"), fn(n: Int) { n })
    == Error(service.ServiceError(service.E500xInternalServerError, "db locked"))
}
