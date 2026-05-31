import driver/http/router
import gleam/list
import gleeunit
import gleeunit/should

pub fn main() -> Nil {
  gleeunit.main()
}

pub fn route_table_contains_all_mvp_endpoints_test() {
  let routes = router.routes()
  should.equal(list.length(routes), 12)
}

pub fn route_table_contains_import_latest_status_endpoint_test() {
  let has_route =
    list.any(router.routes(), fn(route) {
      case route {
        router.HttpRoute(router.Get, "/api/import/latest", _) -> True
        _ -> False
      }
    })

  should.equal(has_route, True)
}

pub fn route_table_contains_settings_endpoint_test() {
  let has_route =
    list.any(router.routes(), fn(route) {
      case route {
        router.HttpRoute(router.Get, "/api/settings", _) -> True
        _ -> False
      }
    })

  should.equal(has_route, True)
}

pub fn route_table_contains_skir_rpc_endpoint_test() {
  let has_route =
    list.any(router.routes(), fn(route) {
      case route {
        router.HttpRoute(router.Post, "/api/skir", _) -> True
        _ -> False
      }
    })

  should.equal(has_route, True)
}
