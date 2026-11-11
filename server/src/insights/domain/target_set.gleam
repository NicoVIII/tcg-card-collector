import gleam/result
import shared/domain/set_code.{type SetCode, type SetCodeError}

pub type TargetSet {
  TargetSet(set_code: SetCode)
}

/// Canonicalises user-typed input (` GRN ` → `grn`) so a target always
/// matches the catalog's and the collection's spelling of its set.
pub fn parse(raw: String) -> Result(TargetSet, SetCodeError) {
  set_code.from_user_input(raw)
  |> result.map(TargetSet)
}

pub fn to_string(target: TargetSet) -> String {
  set_code.to_string(target.set_code)
}
