import birl/duration
import gametime/clients/client_manager.{CreateRoom, RoomChanged}
import gametime/context
import gametime/model
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/json
import gleam/option.{None}
import gleam/result
import wisp
import youid/uuid

fn clock_decoder() -> decode.Decoder(model.Clock) {
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

fn room_decoder() -> decode.Decoder(model.Room) {
  use clocks <- decode.field("clocks", decode.list(clock_decoder()))
  decode.success(model.Room(id: uuid.v4_string(), clocks:, active_clock: None))
}

pub fn create_room(req, ctx: context.Context) {
  use <- wisp.require_method(req, Post)

  use json_data <- wisp.require_json(req)
  let response = {
    use room <- result.try(decode.run(json_data, room_decoder()))

    // TODO: Insert the new room in the DB

    process.send(ctx.client_manager, CreateRoom(room.id))

    let object = json.object([#("id", json.string(room.id))])
    Ok(json.to_string_tree(object))
  }

  case response {
    Ok(json) -> wisp.json_response(json, 200)
    Error(_) -> wisp.unprocessable_entity()
  }
}

pub fn press_clock(req, ctx: context.Context, clock_id) {
  use <- wisp.require_method(req, Post)

  // TODO: Update room state
  // Store in DB
  // Broadcast changed
  let dummy_room =
    model.Room(id: clock_id, active_clock: None, clocks: [
      model.Clock(
        id: clock_id,
        label: "Heya!",
        increment: duration.seconds(10),
        initial_value: duration.seconds(200),
        current_value: duration.milli_seconds(103820),
      ),
    ])

  process.send(ctx.client_manager, RoomChanged(dummy_room))

  wisp.response(204)
}
