import gametime/api/dto.{type RoomDTO, type ClockDTO}
import birl/duration
import gametime/model
import gleam/dynamic/decode
import gleam/option.{None}
import youid/uuid

fn new_clock_decoder() -> decode.Decoder(ClockDTO) {
  use label <- decode.field("label", decode.string)
  use increment_milliseconds <- decode.field("increment_milliseconds", decode.int)
  use initial_milliseconds <- decode.field("initial_milliseconds", decode.int)

  decode.success(dto.ClockDTO(
    id: uuid.v4_string(),
    label:,
    increment_milliseconds:,
    initial_milliseconds:,
    current_milliseconds: initial_milliseconds,
    ends_at: None,
  ))
}

fn new_room_decoder() -> decode.Decoder(RoomDTO) {
  use clocks <- decode.field("clocks", decode.list(new_clock_decoder()))
  decode.success(dto.RoomDTO(id: uuid.v4_string(), clocks:, active_clock: None))
}

pub fn create_room_request(json_data) {
  decode.run(json_data, new_room_decoder())
}
