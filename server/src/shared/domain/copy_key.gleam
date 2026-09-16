import gleam/result
import shared/domain/card_key.{type CardKey, type CardKeyError}
import shared/domain/finish.{type Finish, type FinishError}
import shared/domain/language.{type Language, type LanguageError}

// The identity of a kind of owned physical copy: a printing plus finish and
// language (ADR 0010). CardKey alone still identifies the printing; two copies
// sharing a CardKey but differing in finish or language are different physical
// cards.
pub opaque type CopyKey {
  CopyKey(card_key: CardKey, finish: Finish, language: Language)
}

pub type CopyKeyError {
  InvalidCardKey(CardKeyError)
  InvalidFinish(FinishError)
  InvalidLanguage(LanguageError)
}

/// Builds a CopyKey from already-validated parts — used where the CardKey,
/// Finish, and Language are typed domain values already (e.g. composing a
/// PlannedCard's own fields), so there is nothing left to fail.
pub fn from_parts(
  card_key card_key: CardKey,
  finish finish: Finish,
  language language: Language,
) -> CopyKey {
  CopyKey(card_key:, finish:, language:)
}

/// Strict constructor — accepts only already-canonical parts (as read back
/// from storage). Use from_user_input when the value comes from human-
/// supplied text.
pub fn new(
  set_code set_code: String,
  collector_number collector_number: String,
  finish raw_finish: String,
  language raw_language: String,
) -> Result(CopyKey, CopyKeyError) {
  use card_key <- result.try(
    card_key.new(set_code:, collector_number:)
    |> result.map_error(InvalidCardKey),
  )
  use finish <- result.try(
    finish.new(raw_finish) |> result.map_error(InvalidFinish),
  )
  use language <- result.try(
    language.new(raw_language) |> result.map_error(InvalidLanguage),
  )
  Ok(CopyKey(card_key:, finish:, language:))
}

/// Lenient constructor for user-supplied text (import rows, manual add,
/// mark/unmark placement): canonicalizes each component before validating.
pub fn from_user_input(
  set_code set_code: String,
  collector_number collector_number: String,
  finish raw_finish: String,
  language raw_language: String,
) -> Result(CopyKey, CopyKeyError) {
  use card_key <- result.try(
    card_key.from_user_input(set_code:, collector_number:)
    |> result.map_error(InvalidCardKey),
  )
  use finish <- result.try(
    finish.from_user_input(raw_finish) |> result.map_error(InvalidFinish),
  )
  use language <- result.try(
    language.from_user_input(raw_language)
    |> result.map_error(InvalidLanguage),
  )
  Ok(CopyKey(card_key:, finish:, language:))
}

pub fn card_key(key: CopyKey) -> CardKey {
  key.card_key
}

pub fn finish(key: CopyKey) -> Finish {
  key.finish
}

pub fn language(key: CopyKey) -> Language {
  key.language
}

pub fn set_code_string(key: CopyKey) -> String {
  card_key.set_code_string(key.card_key)
}

pub fn collector_number_string(key: CopyKey) -> String {
  card_key.collector_number_string(key.card_key)
}

pub fn finish_string(key: CopyKey) -> String {
  finish.to_string(key.finish)
}

pub fn language_string(key: CopyKey) -> String {
  language.to_string(key.language)
}

/// Human-readable description of a validation failure, for error reporting
/// at parse boundaries.
pub fn describe_error(error: CopyKeyError) -> String {
  case error {
    InvalidCardKey(card_key_error) -> card_key.describe_error(card_key_error)
    InvalidFinish(finish.Unknown) -> "unknown finish"
    InvalidLanguage(language.Unknown) -> "unknown language"
  }
}
