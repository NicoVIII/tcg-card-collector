pub type CardCatalogTerm {
  CatalogCard
  CatalogSyncRun
  CardIdentity
  CardAttributes
}

pub fn bounded_context_name() -> String {
  "card_catalog"
}

pub fn ubiquitous_language() -> List(String) {
  [
    "CatalogCard",
    "CatalogSyncRun",
    "CardIdentity",
    "CardAttributes",
  ]
}
