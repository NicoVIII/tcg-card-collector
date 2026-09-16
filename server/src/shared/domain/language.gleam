import gleam/string

// The closed set of Scryfall `lang` codes a printed card can carry (ADR 0010).
// No ordering here — "English first" or any other preference is a consuming
// context's policy, not a fact about the language itself.
pub type Language {
  En
  Es
  Fr
  De
  It
  Pt
  Ja
  Ko
  Ru
  Zhs
  Zht
  He
  La
  Grc
  Ar
  Sa
  Ph
  Qya
}

pub type LanguageError {
  Unknown
}

/// Strict constructor — accepts only the canonical lowercase Scryfall code.
/// Use from_user_input when the value comes from human-supplied text.
pub fn new(raw: String) -> Result(Language, LanguageError) {
  case raw {
    "en" -> Ok(En)
    "es" -> Ok(Es)
    "fr" -> Ok(Fr)
    "de" -> Ok(De)
    "it" -> Ok(It)
    "pt" -> Ok(Pt)
    "ja" -> Ok(Ja)
    "ko" -> Ok(Ko)
    "ru" -> Ok(Ru)
    "zhs" -> Ok(Zhs)
    "zht" -> Ok(Zht)
    "he" -> Ok(He)
    "la" -> Ok(La)
    "grc" -> Ok(Grc)
    "ar" -> Ok(Ar)
    "sa" -> Ok(Sa)
    "ph" -> Ok(Ph)
    "qya" -> Ok(Qya)
    _ -> Error(Unknown)
  }
}

/// Lenient constructor for user-supplied text: trims and lowercases first.
pub fn from_user_input(raw: String) -> Result(Language, LanguageError) {
  new(raw |> string.trim |> string.lowercase)
}

pub fn to_string(language: Language) -> String {
  case language {
    En -> "en"
    Es -> "es"
    Fr -> "fr"
    De -> "de"
    It -> "it"
    Pt -> "pt"
    Ja -> "ja"
    Ko -> "ko"
    Ru -> "ru"
    Zhs -> "zhs"
    Zht -> "zht"
    He -> "he"
    La -> "la"
    Grc -> "grc"
    Ar -> "ar"
    Sa -> "sa"
    Ph -> "ph"
    Qya -> "qya"
  }
}
