import clock/clock
import gleam/dynamic/decode
import gleam/float
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/time/duration
import gleam/time/timestamp
import lobby/lobby
import sqlight

pub type Context {
  Context(conn: sqlight.Connection)
}

pub type DbError {
  SqlightErr(sqlight.Error)
  NotFoundErr
  InvalidTimestamp
}

pub fn init_db(conn) {
  "
    CREATE TABLE IF NOT EXISTS lobbies (
      id TEXT NOT NULL,
      name TEXT NOT NULL,
      created_at DATETIME NOT NULL
    );

    CREATE TABLE IF NOT EXISTS seats (
      id TEXT NOT NULL,
      name TEXT NULL,
      lobby_id TEXT NOT NULL,
      created_at DATETIME NOT NULL
    );

    CREATE TABLE IF NOT EXISTS clock_events (
      seat_id TEXT NOT NULL,
      event_type TEXT NOT NULL,
      event_data TEXT NULL,
      created_at DATETIME NOT NULL
    );
  "
  |> sqlight.exec(conn)
}

pub fn insert_events(events: List(lobby.SeatEvent), ctx: Context) {
  let value_text =
    events
    |> list.map(fn(_) { "(?, ?, ?, ?)" })
    |> string.join(",")
  let values =
    events
    |> list.flat_map(fn(se) {
      [
        sqlight.text(se.seat_id),
        sqlight.text(event_type_text(se.event)),
        sqlight.nullable(sqlight.text, event_data_text(se.event)),
        sqlight.text(event_time_text(se.event)),
      ]
    })

  let sql = "
    INSERT INTO clock_events (seat_id, event_type, event_data, created_at) VALUES " <> value_text <> ";"
  sqlight.query(sql, ctx.conn, values, decode.dynamic)
}

/// Create the lobby in the db!! Yippee
pub fn save_lobby(lobby: lobby.Lobby, ctx: Context) {
  // Result of the transaction
  // We save this result so we can rollback if the result is Error()
  // TODO: Can we reduce the nesting ? Maybe the use keyword can help here?
  let trans_result =
    // Start the transaction
    sqlight.exec("BEGIN TRANSACTION;", ctx.conn)
    |> result.map(fn(_) {
      // Insert the lobby record
      "
      INSERT INTO lobbies (id, name, created_at)
      VALUES (?, ?, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'));
      "
      |> sqlight.query(
        ctx.conn,
        [sqlight.text(lobby.id), sqlight.text(lobby.name)],
        decode.dynamic,
      )
    })
    // TODO: Its annoying to have these flattens after every call
    |> result.flatten
    |> result.map(fn(_) {
      // The sqlight library doesnt have a lot of auto parametization, so we do it manually here
      // Build out the full flat array of all values we parameterizationing
      let seat_values =
        lobby.seats
        |> list.flat_map(fn(s) {
          [
            sqlight.text(s.id),
            sqlight.nullable(sqlight.text, s.name),
            sqlight.text(lobby.id),
          ]
        })
      // Get the string to put after VALUES in the sql statement
      let seat_query_text =
        lobby.seats
        |> list.map(fn(_) { "(?, ?, ?, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))" })
        |> string.join(",")

      // Insert all the seats B)
      let sql2 = "
      INSERT INTO seats (id, name, lobby_id, created_at)
      VALUES " <> seat_query_text <> ";"
      sqlight.query(sql2, ctx.conn, seat_values, decode.dynamic)
    })
    |> result.flatten
    |> result.map(fn(_) {
      // Insert all the clock events
      // TODO: Should we just init this to a blank array? Delete some code
      let clock_values =
        lobby.seats
        |> list.flat_map(fn(s) {
          s.clock
          |> list.flat_map(fn(c) {
            let #(ctype, cdur) = {
              case c {
                clock.Add(_, d) -> #("Add", Some(duration.to_seconds(d)))
                clock.Start(_) -> #("Start", None)
                clock.Stop(_) -> #("Stop", None)
              }
            }

            [
              sqlight.text(s.id),
              sqlight.text(ctype),
              sqlight.nullable(sqlight.float, cdur),
            ]
          })
        })

      let clock_query_text =
        lobby.seats
        |> list.map(fn(_) { "(?, ?, ?, strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))" })
        |> string.join(",")

      let sql3 = "
      INSERT INTO clock_events (seat_id, event_type, event_data, created_at)
      VALUES " <> clock_query_text <> ";"
      sqlight.query(sql3, ctx.conn, clock_values, decode.dynamic)
    })
    |> result.map(fn(_) { sqlight.exec("COMMIT TRANSACTION;", ctx.conn) })
    |> result.flatten

  // If the transaction succeeded, then yippee
  // Otherwise, rollback and un-yippee
  case trans_result {
    Ok(v) -> Ok(v)
    Error(v) -> {
      let _ = sqlight.exec("ROLLBACK TRANSACTION;", ctx.conn)
      Error(v)
    }
  }
}

pub fn get_lobby(lobby_id, ctx: Context) {
  // The idea here is that we load ALL the events for a lobby, with the lobby metadata duplicated
  //
  // Then we can fold over all rows, to collect up the lobby and the individual clocks
  // Kind of complicated. I hope I can write it cleanly. Im sorry whoever is reading this.
  let sql =
    "
    SELECT
      l.id as lobby_id
    , l.name as lobby_name
    , s.id as seat_id
    , s.name as seat_name
    , ce.event_type
    , ce.event_data
    , ce.created_at as event_created_at

    FROM lobbies l
    INNER JOIN seats s ON s.lobby_id = l.id
    LEFT JOIN clock_events ce ON ce.seat_id = s.id
    WHERE l.id = ?
  "

  sqlight.query(sql, ctx.conn, [sqlight.text(lobby_id)], lobby_decoder())
  |> result.map_error(SqlightErr)
  |> result.map(list.fold(_, lobby.Lobby("", "", []), fold_lobby))
  |> result.map(fn(lobby) {
    // If we got our fold input lobby as the result, then we got no rows from the db
    case lobby == lobby.Lobby("", "", []) {
      True -> Error(NotFoundErr)
      False -> Ok(lobby)
    }
  })
  |> result.flatten
}

type GetLobbyRow {
  GetLobbyRow(
    lobby_id: String,
    lobby_name: String,
    seat_id: String,
    seat_name: Option(String),
    event_type: String,
    event_data: Option(String),
    event_time: String,
  )
}

fn clock_event(row: GetLobbyRow) {
  case timestamp.parse_rfc3339(row.event_time) {
    Ok(event_time) -> {
      case row.event_type {
        "Start" -> clock.Start(event_time)
        "Stop" -> clock.Stop(event_time)
        "Add" -> {
          let millies =
            row.event_data
            |> option.map(float.parse)
            |> option.unwrap(Error(Nil))
            |> result.unwrap(0.0)
            |> float.multiply(1000.0)
            |> float.truncate

          clock.Add(event_time, duration.milliseconds(millies))
        }
        _ -> {
          echo "Uh oh! Invalid event type! Returning a dummy event"
          clock.Add(event_time, duration.seconds(0))
        }
      }
    }
    Error(_) -> {
      echo "Uh oh! Invalid timestamp! Returning a dummy event"
      clock.Add(timestamp.from_unix_seconds(1), duration.seconds(0))
    }
  }
}

/// Takes a Lobby, and a row from the GetLobbyRow SQL query. It then "folds" the row into the lobby (like baking or smthn)
fn fold_lobby(current: lobby.Lobby, row: GetLobbyRow) {
  // Either add a new seat, or update an existing one, then return the lobby with these fresh seats
  add_or_update_seat(current.seats, row)
  |> lobby.Lobby(id: row.lobby_id, name: row.lobby_name, seats: _)
}

/// Returns an updated List(lobby.Seat), either by prepending a new Seat, or updating an existing one
fn add_or_update_seat(seats: List(lobby.Seat), row: GetLobbyRow) {
  // Go through each seat on the current lobby, if its matching the seat_id, then we update the record, and wrap it with Ok(), otherwise we just wrap with Error() 
  // We wrap like this so we can check later if we need to append a new seat
  let clock_event = clock_event(row)
  let updated_seats =
    seats
    |> list.map(fn(seat) {
      case row.seat_id == seat.id {
        False -> Error(seat)
        True -> {
          // Its a match! Add the clock event
          let new_clock = [clock_event, ..seat.clock]
          Ok(lobby.Seat(id: seat.id, name: seat.name, clock: new_clock))
        }
      }
    })

  // Did we update any records?
  let was_seat_updated =
    updated_seats
    |> list.any(result.is_ok)

  // Add a fresh seat if needed, and unwrap out of the result type
  case was_seat_updated {
    False -> [
      Ok(lobby.Seat(id: row.seat_id, name: row.seat_name, clock: [clock_event])),
      ..updated_seats
    ]
    True -> updated_seats
  }
  |> list.map(result.unwrap_both)
}

fn lobby_decoder() {
  // This decoder is going to be given a tuple of dynamic values, a SQL row is what it is
  use lobby_id <- decode.field(0, decode.string)
  use lobby_name <- decode.field(1, decode.string)
  use seat_id <- decode.field(2, decode.string)
  use seat_name <- decode.field(3, decode.optional(decode.string))

  // Load all the event information
  use event_type <- decode.field(4, decode.string)
  use event_data <- decode.field(5, decode.optional(decode.string))
  use event_time <- decode.field(6, decode.string)

  decode.success(GetLobbyRow(
    lobby_id:,
    lobby_name:,
    seat_id:,
    seat_name:,
    event_type:,
    event_data:,
    event_time:,
  ))
}

/// Gets the text representation of a clock event type for persisting
fn event_type_text(event) {
  case event {
    clock.Add(_, _) -> "Add"
    clock.Start(_) -> "Start"
    clock.Stop(_) -> "Stop"
  }
}

/// Gets the text representation of clock event data for persisting
fn event_data_text(event) {
  case event {
    clock.Add(_, d) ->
      duration.to_seconds(d) |> float.to_precision(3) |> float.to_string |> Some
    _ -> None
  }
}

/// Gets the text representation of when the clock event occurred
fn event_time_text(event) {
  case event {
    clock.Add(t, _) -> timestamp.to_rfc3339(t, duration.seconds(0))
    clock.Start(t) -> timestamp.to_rfc3339(t, duration.seconds(0))
    clock.Stop(t) -> timestamp.to_rfc3339(t, duration.seconds(0))
  }
}
