import gleam/erlang/process.{type Subject}
import gleam/otp/actor

type Msg(a) {
  Get(reply_to: Subject(a))
  Set(value: a)
}

pub opaque type Ref(a) {
  Ref(subject: Subject(Msg(a)))
}

pub fn new(initial: a) -> Ref(a) {
  let assert Ok(started) =
    actor.new(initial)
    |> actor.on_message(fn(state, msg) {
      case msg {
        Get(reply_to) -> {
          process.send(reply_to, state)
          actor.continue(state)
        }
        Set(value) -> actor.continue(value)
      }
    })
    |> actor.start
  Ref(started.data)
}

pub fn get(ref: Ref(a)) -> a {
  process.call(ref.subject, 100, Get)
}

pub fn set(ref: Ref(a), value: a) -> Nil {
  process.send(ref.subject, Set(value))
}
