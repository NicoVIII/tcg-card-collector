import shared/domain/card_key
import shared/domain/copy_key.{InvalidCardKey, InvalidFinish, InvalidLanguage}
import shared/domain/finish
import shared/domain/language
import shared/domain/set_code

// ── new (strict constructor) ──────────────────────────────────────────────

pub fn new_accepts_canonical_parts_test() {
  let assert Ok(key) =
    copy_key.new(
      set_code: "m11",
      collector_number: "146",
      finish: "foil",
      language: "de",
    )
  assert copy_key.finish(key) == finish.Foil
  assert copy_key.language(key) == language.De
}

pub fn new_rejects_uppercase_finish_test() {
  assert copy_key.new(
      set_code: "m11",
      collector_number: "146",
      finish: "FOIL",
      language: "en",
    )
    == Error(InvalidFinish(finish.Unknown))
}

// ── from_user_input ────────────────────────────────────────────────────────

pub fn from_user_input_accepts_canonical_parts_test() {
  let assert Ok(key) =
    copy_key.from_user_input(
      set_code: "m11",
      collector_number: "146",
      finish: "foil",
      language: "de",
    )
  assert copy_key.finish(key) == finish.Foil
  assert copy_key.language(key) == language.De
}

pub fn from_user_input_canonicalizes_finish_and_language_test() {
  let assert Ok(key) =
    copy_key.from_user_input(
      set_code: "m11",
      collector_number: "146",
      finish: " FOIL ",
      language: " DE ",
    )
  assert copy_key.finish_string(key) == "foil"
  assert copy_key.language_string(key) == "de"
}

pub fn from_user_input_propagates_card_key_error_test() {
  assert copy_key.from_user_input(
      set_code: "",
      collector_number: "146",
      finish: "nonfoil",
      language: "en",
    )
    == Error(InvalidCardKey(card_key.InvalidSetCode(set_code.Empty)))
}

pub fn from_user_input_rejects_unknown_finish_test() {
  assert copy_key.from_user_input(
      set_code: "m11",
      collector_number: "146",
      finish: "shiny",
      language: "en",
    )
    == Error(InvalidFinish(finish.Unknown))
}

pub fn from_user_input_rejects_unknown_language_test() {
  assert copy_key.from_user_input(
      set_code: "m11",
      collector_number: "146",
      finish: "nonfoil",
      language: "klingon",
    )
    == Error(InvalidLanguage(language.Unknown))
}

// ── from_parts ─────────────────────────────────────────────────────────────

pub fn from_parts_composes_the_given_values_test() {
  let assert Ok(card_key) =
    card_key.new(set_code: "m11", collector_number: "146")
  let key =
    copy_key.from_parts(card_key:, finish: finish.Etched, language: language.Ja)
  assert copy_key.card_key(key) == card_key
  assert copy_key.finish(key) == finish.Etched
  assert copy_key.language(key) == language.Ja
}
