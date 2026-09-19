import gleam/list
import shared/application/event_bus
import support/ref

fn recording_subscriber(
  seen: ref.Ref(List(String)),
  label: String,
) -> fn(Nil) -> Result(Nil, String) {
  fn(_event) {
    ref.set(seen, list.append(ref.get(seen), [label]))
    Ok(Nil)
  }
}

pub fn publish_runs_every_subscriber_in_order_test() {
  let seen = ref.new([])
  let bus =
    event_bus.new([
      recording_subscriber(seen, "a"),
      recording_subscriber(seen, "b"),
    ])

  assert event_bus.publish(bus, Nil) == Ok(Nil)
  assert ref.get(seen) == ["a", "b"]
}

pub fn publish_stops_at_the_first_failure_and_returns_it_test() {
  let seen = ref.new([])
  let bus =
    event_bus.new([
      recording_subscriber(seen, "a"),
      fn(_event) { Error("second subscriber failed") },
      recording_subscriber(seen, "unreachable"),
    ])

  assert event_bus.publish(bus, Nil) == Error("second subscriber failed")
  assert ref.get(seen) == ["a"]
}

pub fn publish_passes_the_published_event_to_every_subscriber_test() {
  let bus =
    event_bus.new([
      fn(event) {
        case event == 42 {
          True -> Ok(Nil)
          False -> Error("subscriber saw the wrong event")
        }
      },
    ])

  assert event_bus.publish(bus, 42) == Ok(Nil)
}
