import gleam/list

/// A payload-typed publish/subscribe list, built once at composition time.
/// Lets a producer in one bounded context notify a consumer in another
/// without either importing the other — only whoever builds the bus (the
/// composition root) needs to know both sides.
pub opaque type EventBus(event) {
  EventBus(subscribers: List(fn(event) -> Result(Nil, String)))
}

pub fn new(
  subscribers: List(fn(event) -> Result(Nil, String)),
) -> EventBus(event) {
  EventBus(subscribers: subscribers)
}

/// Runs every subscriber inline, in order. The first failure stops the run
/// and is returned — a subscriber that must not block the publisher should
/// catch its own errors and always return `Ok`, not rely on this to swallow
/// them.
pub fn publish(bus: EventBus(event), event: event) -> Result(Nil, String) {
  list.try_each(bus.subscribers, fn(subscriber) { subscriber(event) })
}
