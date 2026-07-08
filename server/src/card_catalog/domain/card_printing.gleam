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
    // Enrichment attributes carried verbatim from the catalog source. Catalog
    // owns these as opaque strings; inventory_planning parses them at its port
    // boundary, so an empty value here is tolerated (e.g. reversible layouts
    // that expose no top-level oracle_id/type_line).
    oracle_id: String,
    color_identity: String,
    type_line: String,
    released_at: String,
  )
}
