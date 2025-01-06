import gleam/option.{type Option}

pub type ClockDTO {
  ClockDTO(
    id: String,
    label: String,
    increment_milliseconds: Int,
    initial_milliseconds: Int,
    current_milliseconds: Int,
    ends_at: Option(Int),
  )
}

pub type RoomDTO {
  RoomDTO(id: String, clocks: List(ClockDTO), active_clock: Option(String))
}
