import catalog/domain/card_rarity.{type CardRarity}
import common/card_key.{type CardKey}
import common/non_empty_string.{type NonEmptyString}

pub type ImageUri {
  ImageUri(String)
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
    image_uri: ImageUri,
  )
}
