import gleam/http/request
import gleam/option.{None, Some}
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

fn request_with_query(query: String) -> request.Request(String) {
  request.Request(..request.new(), query: Some(query))
}

pub fn query_param_finds_a_present_key_test() {
  assert helpers.query_param(request_with_query("name=bolt&set=lea"), "set")
    == Some("lea")
}

pub fn query_param_is_none_when_absent_test() {
  assert helpers.query_param(request_with_query("name=bolt"), "set") == None
}

pub fn query_param_is_none_on_a_malformed_query_string_test() {
  assert helpers.query_param(request_with_query("%"), "name") == None
}

pub fn int_query_param_defaults_when_absent_test() {
  assert helpers.int_query_param(request_with_query(""), "offset", 25) == Ok(25)
}

pub fn int_query_param_parses_a_present_value_test() {
  assert helpers.int_query_param(request_with_query("offset=10"), "offset", 0)
    == Ok(10)
}

pub fn int_query_param_errors_on_a_non_integer_value_test() {
  assert helpers.int_query_param(request_with_query("offset=abc"), "offset", 0)
    == Error("invalid offset query parameter")
}
