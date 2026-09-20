import gleam/http/response.{type Response}
import gleam/json
import mist
import shared/application/app_version.{type AppVersion}
import shared/driver/http/helpers

pub fn encode(app_version: AppVersion) -> String {
  json.object([#("version", json.string(app_version.version))])
  |> json.to_string
}

pub fn handle(app_version: AppVersion) -> Response(mist.ResponseData) {
  helpers.json_response(200, encode(app_version))
}
