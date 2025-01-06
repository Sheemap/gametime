import birl/duration
import gametime/model
import gleam/dynamic/decode
import gleam/option.{None}
import youid/uuid

fn new_clock_decoder() -> decode.Decoder(model.Clock) {
  use label <- decode.field("label", decode.string)
  use increment_int <- decode.field("increment", decode.int)
  use initial_int <- decode.field("initial_time", decode.int)

  let increment = duration.seconds(increment_int)
  let initial_value = duration.seconds(initial_int)

  decode.success(model.Clock(
    id: uuid.v4_string(),
    label:,
    increment:,
    initial_value:,
    current_value: initial_value,
  ))
}

fn new_room_decoder() -> decode.Decoder(model.Room) {
  use clocks <- decode.field("clocks", decode.list(new_clock_decoder()))
  decode.success(model.Room(id: uuid.v4_string(), clocks:, active_clock: None))
}

pub fn create_room_request(json_data) {
  decode.run(json_data, new_room_decoder())
}
