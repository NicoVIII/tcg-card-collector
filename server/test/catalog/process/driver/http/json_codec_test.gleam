import catalog/driver/http/json_codec
import catalog/driver/refresh_launcher

pub fn refresh_started_encodes_started_message_test() {
  assert json_codec.encode_refresh_launch(refresh_launcher.RefreshStarted)
    == "{\"ok\":\"catalog refresh started\"}"
}

pub fn already_running_encodes_running_message_test() {
  assert json_codec.encode_refresh_launch(
      refresh_launcher.RefreshAlreadyRunning,
    )
    == "{\"ok\":\"catalog refresh already running\"}"
}
