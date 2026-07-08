import card_catalog/application/commands/refresh/handler.{RefreshCatalogCommand} as refresh_handler
import card_catalog/driver/dependencies.{type Dependencies}
import gleam/erlang/process
import gleam/io

pub type RefreshLaunchOutcome {
  RefreshStarted
  RefreshAlreadyRunning
}

/// Fire-and-accept: starts the refresh in a background worker registered
/// under `refresh_worker_name`, deduping concurrent triggers regardless of
/// which transport (HTTP or skir) issued them.
pub fn launch(
  deps: Dependencies,
  refresh_worker_name: process.Name(Nil),
  trigger: String,
) -> RefreshLaunchOutcome {
  let refresh_subject = process.named_subject(refresh_worker_name)

  case process.subject_owner(refresh_subject) {
    Ok(_) -> {
      log("already running, skipped trigger: " <> trigger)
      RefreshAlreadyRunning
    }
    Error(_) -> {
      let _ =
        process.spawn_unlinked(fn() {
          case process.register(process.self(), refresh_worker_name) {
            Ok(_) -> {
              log("started: " <> trigger)
              case
                refresh_handler.execute(
                  RefreshCatalogCommand,
                  deps.refresh_catalog_ports,
                )
              {
                Ok(Nil) -> log("finished successfully: " <> trigger)
                Error(_) -> log("finished with failure: " <> trigger)
              }
              Nil
            }
            Error(_) -> {
              log("registration race, skipping: " <> trigger)
              Nil
            }
          }
        })

      RefreshStarted
    }
  }
}

fn log(message: String) -> Nil {
  io.println("[async][catalog-refresh] " <> message)
}
