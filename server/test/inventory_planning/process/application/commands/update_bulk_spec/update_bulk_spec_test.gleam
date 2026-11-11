import inventory_planning/application/commands/update_bulk_spec/handler
import inventory_planning/application/commands/update_bulk_spec/ports
import support/ref

fn recording_port(
  written: ref.Ref(List(ports.BulkSpecWriteModel)),
) -> ports.UpdateBulkSpecPort {
  ports.UpdateBulkSpecPort(update: fn(model) {
    ref.set(written, [model, ..ref.get(written)])
    Ok(Nil)
  })
}

pub fn bulk_spec_is_stored_trimmed_and_canonicalized_test() {
  let written = ref.new([])

  let result =
    handler.execute(
      handler.UpdateBulkSpecCommand(
        location_name: "  Bulk box ",
        sort_keys: " name , set_code ",
      ),
      recording_port(written),
    )

  assert result == Ok(Nil)
  assert ref.get(written)
    == [
      ports.BulkSpecWriteModel(
        location_name: "Bulk box",
        sort_keys: "name,set_code",
      ),
    ]
}

pub fn blank_location_name_is_rejected_without_writing_test() {
  let written = ref.new([])

  let result =
    handler.execute(
      handler.UpdateBulkSpecCommand(location_name: "   ", sort_keys: "name"),
      recording_port(written),
    )

  assert result == Error(ports.InvalidLocationName)
  assert ref.get(written) == []
}

pub fn unknown_sort_key_is_rejected_without_writing_test() {
  let written = ref.new([])

  let result =
    handler.execute(
      handler.UpdateBulkSpecCommand(location_name: "Bulk", sort_keys: "power"),
      recording_port(written),
    )

  assert result == Error(ports.InvalidSortKeys)
  assert ref.get(written) == []
}
