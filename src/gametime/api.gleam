import birl/duration
import gametime/clients/client_manager.{RoomChanged}
import gametime/context
import gametime/model
import gametime/sql
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/io
import gleam/json
import gleam/option.{None}
import gleam/result
import pog
import wisp
import youid/uuid

type CreateRoomError {
  SqlError(String)
  DecodeError(List(decode.DecodeError))
}

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

fn insert_clocks(conn: pog.Connection, room_id, clocks: List(model.Clock)) {
  case clocks {
    [c, ..rest] -> {
      let increment = duration.blur_to(c.increment, duration.Second)
      let initial_value = duration.blur_to(c.initial_value, duration.Second)
      use _ <- result.try(sql.new_clock(
        conn,
        c.id,
        room_id,
        c.label,
        increment,
        initial_value,
      ))

      insert_clocks(conn, room_id, rest)
    }
    [] -> Ok(Nil)
  }
}

fn insert_room(conn: pog.Connection, room: model.Room) {
  sql.new_room(conn, room.id)
  |> result.try(fn(_) {insert_clocks(conn, room.id, room.clocks)})
  |> result.map_error(extract_error_message)
}

fn map_transaction_error(err: pog.TransactionError) {
  case err {
    pog.TransactionRolledBack(msg) -> msg
    pog.TransactionQueryError(error) -> extract_error_message(error)
  }
}

fn extract_error_message(err: pog.QueryError) {
  case err {
    pog.ConstraintViolated(msg, _, _) -> msg
    pog.PostgresqlError(_, _, msg) -> msg
    _ -> "Unknown error occurred"
  }
}

pub fn create_room(req, ctx: context.Context) {
  use <- wisp.require_method(req, Post)
  use json_data <- wisp.require_json(req)

  // Decode the JSON, insert into DB, serialize json response
  let response = {
    use room <- result.try(
      decode.run(json_data, room_decoder()) |> result.map_error(DecodeError),
    )

    // Partial application of the function, will pass in the transaction connection
    pog.transaction(ctx.db, insert_room(_, room))
    |> result.map_error(map_transaction_error)
    |> result.try(fn(_) {
      let object = json.object([#("id", json.string(room.id))])
      Ok(json.to_string_tree(object))
    })
    |> result.map_error(SqlError)
  }

  case response {
    Ok(json) -> wisp.json_response(json, 200)
    Error(DecodeError(_)) -> wisp.unprocessable_entity()
    Error(SqlError(msg)) -> {
      wisp.log_error(msg)
      wisp.internal_server_error()
    }
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
        current_value: duration.milli_seconds(103_820),
      ),
    ])

  process.send(ctx.client_manager, RoomChanged(dummy_room))

  wisp.response(204)
}
