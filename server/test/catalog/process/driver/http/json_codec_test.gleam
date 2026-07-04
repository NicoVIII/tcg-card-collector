import catalog/application/queries/get_cards/ports as get_cards_ports
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

pub fn get_cards_body_decodes_keys_test() {
  let body =
    "{\"keys\":[{\"set_code\":\"grn\",\"collector_number\":\"173\"},"
    <> "{\"set_code\":\"m19\",\"collector_number\":\"5\"}]}"
  assert json_codec.decode_get_cards_body(body)
    == Ok(json_codec.GetCardsBody(keys: [#("grn", "173"), #("m19", "5")]))
}

pub fn get_cards_body_rejects_malformed_json_test() {
  assert json_codec.decode_get_cards_body("{\"keys\":")
    == Error("invalid request body")
}

pub fn catalog_card_details_encode_all_attributes_test() {
  let card =
    get_cards_ports.CardReadModel(
      set_code: "grn",
      collector_number: "173",
      name: "Guildmage",
      image_uri: "https://img.example/guildmage.jpg",
      rarity: "rare",
      oracle_id: "o1",
      color_identity: "R",
      type_line: "Creature — Human Wizard",
      released_at: "2018-10-05",
    )
  assert json_codec.encode_catalog_card_details([card])
    == "[{\"set_code\":\"grn\",\"collector_number\":\"173\","
    <> "\"name\":\"Guildmage\","
    <> "\"image_uri\":\"https://img.example/guildmage.jpg\","
    <> "\"rarity\":\"rare\",\"oracle_id\":\"o1\",\"color_identity\":\"R\","
    <> "\"type_line\":\"Creature — Human Wizard\","
    <> "\"released_at\":\"2018-10-05\"}]"
}
