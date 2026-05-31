pub type HttpMethod {
  Get
  Post
  Put
  Delete
}

pub type HttpRoute {
  HttpRoute(method: HttpMethod, path: String, handler_name: String)
}

pub fn routes() -> List(HttpRoute) {
  [
    HttpRoute(Get, "/api/catalog/cards", "card_catalog.list"),
    HttpRoute(Post, "/api/catalog/refresh", "card_catalog.refresh"),
    HttpRoute(Post, "/api/import", "collection_import.import"),
    HttpRoute(Get, "/api/import/latest", "collection_import.latest_status"),
    HttpRoute(Get, "/api/inventory/rules", "inventory.list_rules"),
    HttpRoute(Put, "/api/inventory/rules", "inventory.upsert_rule"),
    HttpRoute(Delete, "/api/inventory/rules", "inventory.delete_rule"),
    HttpRoute(Get, "/api/inventory/projection", "inventory.projection"),
    HttpRoute(Get, "/api/settings", "settings.get"),
    HttpRoute(Put, "/api/settings", "settings.update"),
  ]
}
