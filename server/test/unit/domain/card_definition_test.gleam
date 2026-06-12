import common/non_empty_string
import domain/card_definition

// ---- from_raw happy path ----------------------------------------------------

pub fn from_raw_valid_card_returns_ok_test() {
  let assert Ok(card) =
    card_definition.from_raw(
      id: "test-id-001",
      name: "Black Lotus",
      set_code: "lea",
      collector_number: "232",
      rarity: "rare",
      image_uri: "https://example.com/img.jpg",
    )

  assert card.id == card_definition.CardDefinitionId("test-id-001")
  assert card.name
    == {
      let assert Ok(n) = non_empty_string.new("Black Lotus")
      n
    }
  assert card.set_code
    == {
      let assert Ok(s) = non_empty_string.new("lea")
      s
    }
  assert card.collector_number
    == {
      let assert Ok(c) = non_empty_string.new("232")
      c
    }
  assert card.rarity == card_definition.Rare
  assert card.image_uri
    == card_definition.ImageUri("https://example.com/img.jpg")
}

// ---- from_raw error variants ------------------------------------------------

pub fn from_raw_empty_name_returns_error_test() {
  let result =
    card_definition.from_raw(
      id: "x",
      name: "",
      set_code: "lea",
      collector_number: "1",
      rarity: "common",
      image_uri: "https://example.com/img.jpg",
    )

  assert result == Error(card_definition.EmptyName)
}

pub fn from_raw_empty_set_code_returns_error_test() {
  let result =
    card_definition.from_raw(
      id: "x",
      name: "Test Card",
      set_code: "",
      collector_number: "1",
      rarity: "common",
      image_uri: "https://example.com/img.jpg",
    )

  assert result == Error(card_definition.EmptySetCode)
}

pub fn from_raw_empty_collector_number_returns_error_test() {
  let result =
    card_definition.from_raw(
      id: "x",
      name: "Test Card",
      set_code: "lea",
      collector_number: "",
      rarity: "common",
      image_uri: "https://example.com/img.jpg",
    )

  assert result == Error(card_definition.EmptyCollectorNumber)
}

pub fn from_raw_unknown_rarity_returns_error_test() {
  let result =
    card_definition.from_raw(
      id: "x",
      name: "Test Card",
      set_code: "lea",
      collector_number: "1",
      rarity: "mythical_rare",
      image_uri: "https://example.com/img.jpg",
    )

  assert result == Error(card_definition.UnknownRarity("mythical_rare"))
}

// ---- parse_rarity -----------------------------------------------------------

pub fn parse_rarity_common_test() {
  assert card_definition.parse_rarity("common") == Ok(card_definition.Common)
}

pub fn parse_rarity_uncommon_test() {
  assert card_definition.parse_rarity("uncommon")
    == Ok(card_definition.Uncommon)
}

pub fn parse_rarity_rare_test() {
  assert card_definition.parse_rarity("rare") == Ok(card_definition.Rare)
}

pub fn parse_rarity_mythic_test() {
  assert card_definition.parse_rarity("mythic") == Ok(card_definition.Mythic)
}

pub fn parse_rarity_special_test() {
  assert card_definition.parse_rarity("special") == Ok(card_definition.Special)
}

pub fn parse_rarity_bonus_test() {
  assert card_definition.parse_rarity("bonus") == Ok(card_definition.Bonus)
}

pub fn parse_rarity_unknown_returns_error_test() {
  assert card_definition.parse_rarity("mythical_rare") == Error(Nil)
}
