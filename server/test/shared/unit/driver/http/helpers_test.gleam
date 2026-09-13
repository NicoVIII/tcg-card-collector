import shared/driver/http/helpers
import shared/driver/presented_error.{BadRequest, Internal, PresentedError}

pub fn error_response_maps_classes_to_http_statuses_test() {
  assert helpers.error_response(PresentedError(BadRequest, "bad")).status == 400
  assert helpers.error_response(PresentedError(Internal, "boom")).status == 500
}

pub fn query_response_is_200_on_success_and_500_on_failure_test() {
  assert helpers.query_response(Ok(1), fn(_) { "{}" }).status == 200
  assert helpers.query_response(Error("db locked"), fn(_: Int) { "{}" }).status
    == 500
}
