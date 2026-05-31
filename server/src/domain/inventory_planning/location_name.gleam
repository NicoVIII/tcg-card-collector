import gleam/string

pub opaque type LocationName {
  LocationName(value: String)
}

pub type LocationNameError {
  EmptyLocationName
}

pub fn new(value: String) -> Result(LocationName, LocationNameError) {
  case string.length(value) == 0 {
    True -> Error(EmptyLocationName)
    False -> Ok(LocationName(value))
  }
}

pub fn value(location_name: LocationName) -> String {
  let LocationName(value) = location_name
  value
}
