import birl/duration
import gleam/float
import birl
import gametime/api/decoders
import gametime/clients/client_manager.{RoomChanged}
import gametime/context
import gametime/database
import gametime/model
import gametime/sql
import gleam/dynamic/decode
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import pog
import wisp
import youid/uuid

type CreateRoomError {
  SqlError(String)
  DecodeError(List(decode.DecodeError))
}

type PressClockError {
  ClockNotRunning
}

pub fn create_room(req, ctx: context.Context) {
  use <- wisp.require_method(req, Post)
  use json_data <- wisp.require_json(req)

  // Decode the JSON, insert into DB, serialize json response
  let response = {
    use room <- result.try(
      decoders.create_room_request(json_data) |> result.map_error(DecodeError),
    )

    database.create_room(ctx.db, room)
    |> result.try(fn(_) {
      let object = json.object([#("id", json.string(room.id))])
      Ok(json.to_string_tree(object))
    })
    |> result.map_error(SqlError)
  }

  case response {
    Ok(json) -> wisp.json_response(json, 200)
    // TODO: build some json response detailing what was wrong with request
    Error(DecodeError(_)) -> wisp.unprocessable_entity()
    Error(SqlError(msg)) -> {
      wisp.log_error(msg)
      wisp.internal_server_error()
    }
  }
}

fn find_clock(predicate, result: pog.Returned(sql.GetRoomClocksByClockIdRow)) {
  result.rows
  |> list.find(predicate)
  |> result.map_error(fn(_) { "Clock not found" })
}

fn find_clock_by_id(clock_id, result: pog.Returned(sql.GetRoomClocksByClockIdRow)) {
    find_clock(fn(c) { c.id == clock_id }, result)
}

fn find_clock_by_position(position, result: pog.Returned(sql.GetRoomClocksByClockIdRow)) {
    find_clock(fn(c) { c.position == position }, result)
}

fn next_position(current_pos, clock_count){
// Prevent out of range
    case current_pos + 1 >= clock_count {
        True -> 0
        False -> current_pos +1
    }
}

fn to_clock_model(row: sql.GetRoomClocksByClockIdRow) {
    let increment = duration.milli_seconds(row.increment)
    let initial_value = duration.milli_seconds(row.initial_value)
    let current_value = duration.milli_seconds(row.remaining_time)

    model.Clock(id:row.id, label:row.label, increment:, initial_value:, current_value:)
}

fn update_remaining_time(clock: model.Clock, clock_id, remaining_time) {
    case clock.id == clock_id {
        True -> model.Clock(clock.id, clock.label, clock.increment, clock.initial_value, remaining_time)
        False -> clock

    }
}

pub fn press_clock(req, ctx: context.Context, clock_id) {
  use <- wisp.require_method(req, Post)

  let response = {
    use rows <- result.try(database.get_clock_roommates(ctx.db, clock_id))
    use our_clock <- result.try(find_clock_by_id(clock_id, rows))

    case our_clock.state {
      sql.Add -> Error("Invalid state")
      sql.Stop -> Error("Clock not running")
      sql.Start -> {
      // remaining time is not updated live, its just the latest known remaining time
      // We need to make up the difference by checking updated_at
        let updated_at = our_clock.updated_at |> float.round() |> birl.from_unix_milli()
        let event_age = birl.difference(birl.now(), updated_at)
        let remaining_time = duration.subtract(event_age, duration.milli_seconds(our_clock.remaining_time))

        use next_clock <- result.try(
            next_position(our_clock.position, rows.count)
            |> find_clock_by_position(rows)
        )

        let events = [
            model.ClockEvent(clock_id: our_clock.id, event_type: sql.Stop, remaining_time:, details: None),
            model.ClockEvent(clock_id: next_clock.id, event_type: sql.Start, remaining_time:duration.milli_seconds(next_clock.remaining_time), details: None),
        ]
        use _ <- result.try(database.insert_clock_events(ctx.db, events))


        let new_clocks =
            rows.rows
            |> list.map(to_clock_model)
            |> list.map(update_remaining_time(_, our_clock.id, remaining_time))

        let new_room =
          model.Room(id: our_clock.room_id, active_clock: Some(next_clock.id), clocks: new_clocks)

        process.send(ctx.client_manager, RoomChanged(new_room))
        Ok(Nil)
      }
    }
  }

  case response {
    Ok(_) -> wisp.response(204)
    Error(msg) -> {
      wisp.log_error(msg)
      wisp.internal_server_error()
    }
  }
}
