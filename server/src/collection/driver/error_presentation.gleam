import shared/driver/presented_error.{
  type PresentedError, Internal, PresentedError,
}

/// A persistence failure's fixed client-facing message. AddCards builds this
/// inline on both transports today (issue #87 judged collection exempt from
/// writing error presentation once per use case, since collection's skir
/// side returns typed rejection variants instead of errors) — but that
/// reasoning doesn't cover this arm: both
/// transports leak the raw DB failure reason to clients here. RemoveCards
/// closes that leak; its InvalidRows case keeps the existing rejection-variant
/// shape (issue #45 owns relitigating that shape) and never reaches this
/// function.
pub fn remove_cards(_reason: String) -> PresentedError {
  PresentedError(Internal, "failed to remove cards from the collection")
}
