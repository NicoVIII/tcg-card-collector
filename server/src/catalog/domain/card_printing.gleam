import shared/domain/card_key.{type CardKey}
import shared/domain/non_empty_string.{type NonEmptyString}

pub type CardRarity {
  Common
  Uncommon
  Rare
  Mythic
  Special
  Bonus
}

pub type CardPrintingId {
  CardPrintingId(String)
}

pub type CardPrinting {
  CardPrinting(
    id: CardPrintingId,
    key: CardKey,
    name: NonEmptyString,
    rarity: CardRarity,
    image_uri: NonEmptyString,
  )
}
