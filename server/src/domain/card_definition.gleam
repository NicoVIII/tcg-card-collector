import common/non_empty_string.{type NonEmptyString}
import gleam/result

pub type ImageUri {
  ImageUri(String)
}

pub type CardDefinitionId {
  CardDefinitionId(String)
}

pub type CardRarity {
  Common
  Uncommon
  Rare
  Mythic
  Special
  Bonus
}

pub type CardDefinition {
  CardDefinition(
    id: CardDefinitionId,
    name: NonEmptyString,
    set_code: NonEmptyString,
    collector_number: NonEmptyString,
    rarity: CardRarity,
    image_uri: ImageUri,
  )
}

pub type CardDefinitionError {
  EmptyName
  EmptySetCode
  EmptyCollectorNumber
  UnknownRarity(String)
}

pub fn from_raw(
  id id: String,
  name name: String,
  set_code set_code: String,
  collector_number collector_number: String,
  rarity rarity: String,
  image_uri image_uri: String,
) -> Result(CardDefinition, CardDefinitionError) {
  use name <- result.try(
    non_empty_string.new(name) |> result.map_error(fn(_) { EmptyName }),
  )
  use set_code <- result.try(
    non_empty_string.new(set_code) |> result.map_error(fn(_) { EmptySetCode }),
  )
  use collector_number <- result.try(
    non_empty_string.new(collector_number)
    |> result.map_error(fn(_) { EmptyCollectorNumber }),
  )
  use rarity_value <- result.try(
    parse_rarity(rarity) |> result.map_error(fn(_) { UnknownRarity(rarity) }),
  )
  Ok(CardDefinition(
    id: CardDefinitionId(id),
    name: name,
    set_code: set_code,
    collector_number: collector_number,
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
