import gleam/result
import shared/domain/non_empty_string.{type NonEmptyString}

pub type TargetSet {
  TargetSet(set_code: NonEmptyString)
}

pub fn parse(raw: String) -> Result(TargetSet, Nil) {
  non_empty_string.new(raw)
  |> result.map(TargetSet)
}

pub fn to_string(target: TargetSet) -> String {
  non_empty_string.to_string(target.set_code)
}
