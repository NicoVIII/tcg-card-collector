import gleam/bool
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import inventory_planning/application/commands/complete_location_audit/ports
import inventory_planning/domain/location_audit.{
  type Finding, type LocationAudit, AuditRecord, Missing, Unexpected,
}
import inventory_planning/domain/location_ref.{type LocationRef}
import shared/application/command_result
import shared/domain/copy_key

/// A location as it arrives on the wire: `kind` is "cascade" or "managed".
pub type RawLocation {
  RawLocation(kind: String, key: String)
}

/// One kind of copy and how many, still raw.
pub type RawAuditedCopy {
  RawAuditedCopy(
    set_code: String,
    collector_number: String,
    finish: String,
    language: String,
    quantity: Int,
  )
}

pub type RawUnexpectedCopy {
  RawUnexpectedCopy(copy: RawAuditedCopy, source: Option(RawLocation))
}

pub type CompleteLocationAuditCommand {
  CompleteLocationAuditCommand(
    location: RawLocation,
    missing: List(RawAuditedCopy),
    unexpected: List(RawUnexpectedCopy),
  )
}

fn parse_location(
  raw: RawLocation,
) -> Result(LocationRef, ports.CompleteLocationAuditError) {
  location_ref.new(kind: raw.kind, key: raw.key)
  |> result.replace_error(ports.InvalidAudit)
}

fn parse_copy(
  raw: RawAuditedCopy,
) -> Result(copy_key.CopyKey, ports.CompleteLocationAuditError) {
  copy_key.from_user_input(
    set_code: raw.set_code,
    collector_number: raw.collector_number,
    finish: raw.finish,
    language: raw.language,
  )
  |> result.replace_error(ports.InvalidAudit)
}

fn parse_unexpected(
  raw: RawUnexpectedCopy,
) -> Result(Finding, ports.CompleteLocationAuditError) {
  use key <- result.try(parse_copy(raw.copy))
  use source <- result.map(case raw.source {
    Some(source) -> parse_location(source) |> result.map(Some)
    None -> Ok(None)
  })
  Unexpected(key:, quantity: raw.copy.quantity, source:)
}

fn parse_audit(
  command: CompleteLocationAuditCommand,
) -> Result(LocationAudit, ports.CompleteLocationAuditError) {
  use location <- result.try(parse_location(command.location))
  use missing <- result.try(
    list.try_map(command.missing, fn(raw) {
      use key <- result.map(parse_copy(raw))
      Missing(key:, quantity: raw.quantity)
    }),
  )
  use unexpected <- result.try(list.try_map(
    command.unexpected,
    parse_unexpected,
  ))
  location_audit.new(location, list.append(missing, unexpected))
  |> result.replace_error(ports.InvalidAudit)
}

// A cascade location is computed, not stored, so only a managed one can be
// known not to exist — a deleted deck whose page is still open.
fn guard_location_exists(
  audit: LocationAudit,
  ports: ports.CompleteLocationAuditPorts,
  continue: fn() ->
    command_result.CommandResult(ports.CompleteLocationAuditError),
) -> command_result.CommandResult(ports.CompleteLocationAuditError) {
  case location_audit.location(audit) {
    location_ref.Cascade(_) -> continue()
    location_ref.Managed(id) -> {
      use ids <- result.try(
        ports.managed_location_ids()
        |> result.map_error(ports.PersistenceFailed),
      )
      use <- bool.guard(!list.contains(ids, id), Error(ports.UnknownLocation))
      continue()
    }
  }
}

/// Applies every finding of a completed audit and stamps the location's
/// audit history, atomically (ADR 0024). Abandoning an audit never reaches
/// the server, so nothing here is partial.
pub fn execute(
  command: CompleteLocationAuditCommand,
  ports: ports.CompleteLocationAuditPorts,
) -> command_result.CommandResult(ports.CompleteLocationAuditError) {
  use audit <- result.try(parse_audit(command))
  use <- guard_location_exists(audit, ports)
  use ledger <- result.try(
    ports.list_placed() |> result.map_error(ports.PersistenceFailed),
  )
  use owned <- result.try(
    ports.owned_quantities() |> result.map_error(ports.PersistenceFailed),
  )
  use changes <- result.try(
    location_audit.ledger_changes(audit, ledger, owned)
    |> result.map_error(ports.Rejected),
  )
  let record =
    AuditRecord(
      location: location_audit.location(audit),
      completed_at: ports.now(),
    )
  ports.apply(changes, record)
  |> result.map_error(ports.PersistenceFailed)
}
