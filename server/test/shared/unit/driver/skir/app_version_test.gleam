import shared/application/app_version
import shared/driver/skir/app_version as app_version_skir

pub fn map_app_version_carries_the_version_string_test() {
  assert app_version_skir.map_app_version(app_version.AppVersion(
      "0.1.0-dev+abc1234",
    )).version
    == "0.1.0-dev+abc1234"
}
