import gleam/list
import shared/infrastructure/stores/sqlite_store

pub fn placeholders_repeats_the_row_shape_test() {
  assert sqlite_store.placeholders(3, "(?,?)") == "(?,?), (?,?), (?,?)"
}

pub fn query_in_chunks_concatenates_chunk_results_in_order_test() {
  let result =
    sqlite_store.query_in_chunks([1, 2, 3, 4, 5], 2, fn(chunk) {
      Ok([list.length(chunk)])
    })

  assert result == Ok([2, 2, 1])
}

pub fn query_in_chunks_skips_the_query_for_empty_input_test() {
  let result =
    sqlite_store.query_in_chunks([], 2, fn(_) { Error("must not run") })

  assert result == Ok([])
}

pub fn query_in_chunks_stops_at_the_first_failing_chunk_test() {
  let result =
    sqlite_store.query_in_chunks([1, 2, 3], 1, fn(chunk) {
      case chunk {
        [2] -> Error("chunk 2 failed")
        _ -> Ok(chunk)
      }
    })

  assert result == Error("chunk 2 failed")
}
