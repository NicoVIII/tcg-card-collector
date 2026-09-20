import shared/application/app_version
import shared/driver/http/app_version as app_version_http

pub fn encode_writes_the_version_field_test() {
  assert app_version_http.encode(app_version.AppVersion("0.1.0-dev+abc1234"))
    == "{\"version\":\"0.1.0-dev+abc1234\"}"
}
