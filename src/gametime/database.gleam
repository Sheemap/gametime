import gametime/api/dto
import gleam/float
import birl
import birl/duration
import gametime/model
import gametime/sql
import gleam/list
import gleam/result
import pog

fn to_flat_clock_model(row: sql.GetRoomClocksByClockIdRow) {
  let increment = duration.milli_seconds(row.increment)
  let initial_value = duration.milli_seconds(row.initial_value)
  let current_value = duration.milli_seconds(row.remaining_time)
  let updated_at = birl.from_unix_milli(float.round(row.updated_at))

  model.FlatClock(
    id: row.id,
    room_id: row.room_id,
    label: row.label,
    position:row.position,
    increment:,
    initial_value:,
    current_value:,
    state: row.state,
    updated_at:,
  )
}

fn extract_error_message(err: pog.QueryError) {
  case err {
    pog.ConstraintViolated(msg, _, _) -> msg
    pog.PostgresqlError(_, _, msg) -> msg
    _ -> "Unknown error occurred"
  }
}

fn extract_transaction_error_message(err: pog.TransactionError) {
  case err {
    pog.TransactionRolledBack(msg) -> msg
    pog.TransactionQueryError(error) -> extract_error_message(error)
  }
}

fn insert_clocks(
  conn: pog.Connection,
  room_id,
  index,
  clocks: List(dto.ClockDTO),
) {
  case clocks {
    [c, ..rest] -> {
      use _ <- result.try(sql.new_clock(
        conn,
        c.id,
        room_id,
        c.label,
        index,
        c.increment_milliseconds,
        c.initial_milliseconds,
      ))

      insert_clocks(conn, room_id, index + 1, rest)
    }
    [] -> Ok(Nil)
  }
}

fn insert_room(conn: pog.Connection, room: dto.RoomDTO) {
  sql.new_room(conn, room.id)
  |> result.try(fn(_) { insert_clocks(conn, room.id, 0, room.clocks) })
  |> result.map_error(extract_error_message)
}

pub fn create_room(conn: pog.Connection, room) {
  pog.transaction(conn, insert_room(_, room))
  |> result.map_error(extract_transaction_error_message)
}

pub fn get_clock_roommates(
  conn: pog.Connection,
  clock_id,
) -> Result(List(model.FlatClock), String) {
  sql.get_room_clocks_by_clock_id(conn, clock_id)
  |> result.map_error(extract_error_message)
  |> result.map(fn(res) { res.rows |> list.map(to_flat_clock_model) })
}

fn bulk_insert_clock_events(
  conn: pog.Connection,
  events: List(model.ClockEvent),
) {
  case events {
    [e, ..rest] -> {
      let remaining_time =
        duration.blur_to(e.remaining_time, duration.MilliSecond)
      use _ <- result.try(
        sql.insert_clock_event(conn, e.clock_id, e.event_type, remaining_time)
        |> result.map_error(extract_error_message),
      )
      bulk_insert_clock_events(conn, rest)
    }
    [] -> Ok(Nil)
  }
}

pub fn insert_clock_events(conn: pog.Connection, events: List(model.ClockEvent)) {
  pog.transaction(conn, bulk_insert_clock_events(_, events))
  |> result.map_error(extract_transaction_error_message)
}
