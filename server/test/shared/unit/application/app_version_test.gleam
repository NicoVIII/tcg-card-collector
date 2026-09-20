import shared/application/app_version

pub fn release_channel_uses_the_bare_version_test() {
  assert app_version.compose("0.1.0", "release", "abc1234def")
    == app_version.AppVersion("0.1.0")
}

pub fn dev_channel_appends_a_truncated_commit_test() {
  assert app_version.compose("0.1.0", "dev", "abc1234def")
    == app_version.AppVersion("0.1.0-dev+abc1234")
}

pub fn dev_channel_with_no_commit_falls_back_to_local_test() {
  assert app_version.compose("0.1.0", "dev", "")
    == app_version.AppVersion("0.1.0-dev+local")
}

pub fn any_channel_other_than_release_is_treated_as_dev_test() {
  assert app_version.compose("0.1.0", "unknown", "")
    == app_version.AppVersion("0.1.0-dev+local")
}
