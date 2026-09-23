import gleam/option.{type Option}
import shared/domain/set_code.{type SetCode}

pub type CatalogCardKeyReadModel {
  CatalogCardKeyReadModel(set_code: String, collector_number: String)
}

// name: case-insensitive substring; absent means no name filter.
// set_code: exact match; absent means no set filter.
pub type CatalogCardFilter {
  CatalogCardFilter(name: Option(String), set_code: Option(SetCode))
}

pub type ListCatalogCardsPort {
  ListCatalogCardsPort(
    list_cards: fn(CatalogCardFilter) ->
      Result(List(CatalogCardKeyReadModel), String),
  )
}
