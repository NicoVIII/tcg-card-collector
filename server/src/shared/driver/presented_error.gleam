/// Transport-neutral error classes; each transport maps them to its own
/// status codes.
pub type ErrorClass {
  BadRequest
  Internal
}

/// How a use case's error is shown to clients, written once per use case in
/// `<context>/driver/error_presentation.gleam` so both transports agree.
pub type PresentedError {
  PresentedError(class: ErrorClass, message: String)
}
