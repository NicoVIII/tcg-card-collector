import gleam/option.{type Option}
import shared/domain/card_key.{type CardKey}
import shared/domain/color_identity.{type ColorIdentity}
import shared/domain/mana_value.{type ManaValue}
import shared/domain/non_empty_string.{type NonEmptyString}
import shared/domain/oracle_id.{type OracleId}
import shared/domain/rarity.{type Rarity}
import shared/domain/release_date.{type ReleaseDate}

pub type CardPrintingId {
  CardPrintingId(String)
}

// Enrichment facts are parsed into shared value types once, at the sync
// boundary (ADR 0008). oracle_id, released_at and cmc are Option because
// reversible/multi-face layouts may expose no top-level value; type_line stays
// the raw printed line ("" for the same layout gap) — any reduction of it is
// consumer policy, not a catalog fact.
pub type CardPrinting {
  CardPrinting(
    id: CardPrintingId,
    key: CardKey,
    name: NonEmptyString,
    rarity: Rarity,
    image_uri: NonEmptyString,
    oracle_id: Option(OracleId),
    color_identity: ColorIdentity,
    type_line: String,
    released_at: Option(ReleaseDate),
    cmc: Option(ManaValue),
  )
}
