import common/card_key.{type CardKey}
import common/non_empty_string.{type NonEmptyString}
import gleam/result

pub type ImageUri {
  ImageUri(String)
}

pub type CardPrintingId {
  CardPrintingId(String)
}

pub type CardRarity {
  Common
  Uncommon
  Rare
  Mythic
  Special
  Bonus
}

pub type CardPrinting {
  CardPrinting(
    id: CardPrintingId,
    key: CardKey,
    name: NonEmptyString,
    rarity: CardRarity,
    image_uri: ImageUri,
  )
}

pub type CardPrintingError {
  EmptyName
  EmptySetCode
  EmptyCollectorNumber
  UnknownRarity(String)
}

/// Validate and construct a CardPrinting from raw string fields.
/// Invalid rows (unknown rarity, empty required fields) should be skipped
/// by callers with a per-row warning log. Add new invariant checks here.
pub fn from_raw(
  id id: String,
  name name: String,
  set_code set_code: String,
  collector_number collector_number: String,
  rarity rarity: String,
  image_uri image_uri: String,
) -> Result(CardPrinting, CardPrintingError) {
  use name <- result.try(
    non_empty_string.new(name) |> result.map_error(fn(_) { EmptyName }),
  )
  use key <- result.try(
    card_key.new(set_code: set_code, collector_number: collector_number)
    |> result.map_error(fn(err) {
      case err {
        card_key.EmptySetCode -> EmptySetCode
        card_key.EmptyCollectorNumber -> EmptyCollectorNumber
      }
    }),
  )
  use rarity_value <- result.try(
    parse_rarity(rarity) |> result.map_error(fn(_) { UnknownRarity(rarity) }),
  )
  Ok(CardPrinting(
    id: CardPrintingId(id),
    key: key,
    name: name,
    rarity: rarity_value,
    image_uri: ImageUri(image_uri),
  ))
}

pub fn parse_rarity(raw: String) -> Result(CardRarity, Nil) {
  case raw {
    "common" -> Ok(Common)
    "uncommon" -> Ok(Uncommon)
    "rare" -> Ok(Rare)
    "mythic" -> Ok(Mythic)
    "special" -> Ok(Special)
    "bonus" -> Ok(Bonus)
    _ -> Error(Nil)
  }
}

pub fn rarity_to_string(rarity: CardRarity) -> String {
  case rarity {
    Common -> "common"
    Uncommon -> "uncommon"
    Rare -> "rare"
    Mythic -> "mythic"
    Special -> "special"
    Bonus -> "bonus"
  }
}
