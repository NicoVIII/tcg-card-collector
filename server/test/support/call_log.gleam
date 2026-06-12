import gleam/erlang/process
import gleam/list

pub type Log(a) =
  process.Subject(a)

pub fn new() -> Log(a) {
  process.new_subject()
}

pub fn record(log: Log(a), msg: a) -> Nil {
  process.send(log, msg)
}

pub fn drain(log: Log(a)) -> List(a) {
  drain_loop(log, [])
}

fn drain_loop(log: Log(a), acc: List(a)) -> List(a) {
  case process.receive(log, 0) {
    Error(Nil) -> list.reverse(acc)
    Ok(msg) -> drain_loop(log, [msg, ..acc])
  }
}
