import common/card_key.{type CardKey}
import common/non_empty_string.{type NonEmptyString}

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
