pub opaque type Timestamp {
  Timestamp(epoch_seconds: Int)
}

pub fn from_epoch_seconds(s: Int) -> Timestamp {
  Timestamp(s)
}

pub fn to_epoch_seconds(t: Timestamp) -> Int {
  t.epoch_seconds
}

/// Positive when `later` is after `earlier`.
pub fn difference_seconds(later: Timestamp, earlier: Timestamp) -> Int {
  later.epoch_seconds - earlier.epoch_seconds
}
