import catalog/driver/http/json_codec

pub fn refresh_started_encodes_started_message_test() {
  assert json_codec.encode_refresh_launch(json_codec.RefreshStarted)
    == "{\"ok\":\"catalog refresh started\"}"
}

pub fn already_running_encodes_running_message_test() {
  assert json_codec.encode_refresh_launch(json_codec.RefreshAlreadyRunning)
    == "{\"ok\":\"catalog refresh already running\"}"
}
