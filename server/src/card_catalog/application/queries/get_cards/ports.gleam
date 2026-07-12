import gleam/option.{type Option}
import shared/domain/color_identity.{type ColorIdentity}
import shared/domain/oracle_id.{type OracleId}
import shared/domain/rarity.{type Rarity}
import shared/domain/release_date.{type ReleaseDate}

// Enrichment facts carry the shared value types (ADR 0008); the raw type line
// is the fact, reductions of it are consumer policy. Strings survive only at
// storage/transport seams.
pub type CardReadModel {
  CardReadModel(
    set_code: String,
    collector_number: String,
    name: String,
    image_uri: String,
    rarity: Rarity,
    oracle_id: Option(OracleId),
    color_identity: ColorIdentity,
    type_line: String,
    released_at: Option(ReleaseDate),
  )
}

pub type GetCatalogCardsPort {
  GetCatalogCardsPort(
    get_cards: fn(List(#(String, String))) ->
      Result(List(CardReadModel), String),
  )
}
