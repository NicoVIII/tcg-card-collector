import shared/application/app_version.{type AppVersion}
import shared/driver/skir/helpers
import shared/driver/skir/skirout/system/queries as system_queries
import skir_client/service

pub fn map_app_version(app_version: AppVersion) -> system_queries.AppVersion {
  system_queries.app_version_new(version: app_version.version)
}

fn handle_get_app_version(
  get_app_version: fn(context) -> AppVersion,
) -> helpers.MethodHandler(
  system_queries.GetAppVersionRequest,
  system_queries.AppVersion,
  context,
) {
  fn(_: system_queries.GetAppVersionRequest, _, ctx) {
    get_app_version(ctx)
    |> map_app_version
    |> Ok
    |> helpers.respond
  }
}

pub fn register(
  svc: service.Service(Nil, context, Nil),
  get_app_version: fn(context) -> AppVersion,
) -> service.Service(Nil, context, Nil) {
  svc
  |> service.add_method(
    system_queries.get_app_version_method(),
    handle_get_app_version(get_app_version),
  )
}
