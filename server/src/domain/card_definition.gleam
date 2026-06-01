import common/non_empty_string.{type NonEmptyString}

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
