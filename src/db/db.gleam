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
}

pub fn init_db(conn) {
  "
    CREATE TABLE IF NOT EXISTS lobbies (
      id TEXT NOT NULL,
      name TEXT NOT NULL,
      created_at NUMERIC NOT NULL
    );

    CREATE TABLE IF NOT EXISTS seats (
      id TEXT NOT NULL,
      name TEXT NULL,
      lobby_id TEXT NOT NULL,
      created_at NUMERIC NOT NULL
    );

    CREATE TABLE IF NOT EXISTS clock_events (
      seat_id TEXT NOT NULL,
      event_type TEXT NOT NULL,
      event_data TEXT NULL,
      created_at NUMERIC NOT NULL
    );
  "
  |> sqlight.exec(conn)
}

pub fn save_lobby(lobby: lobby.Lobby, ctx: Context) {
  let now =
    timestamp.system_time()
    |> timestamp.to_unix_seconds
    |> float.truncate

  let sql =
    "
    INSERT INTO lobbies (id, name, created_at)
    VALUES (?, ?, ?);
  "

  sqlight.exec("BEGIN TRANSACTION;", ctx.conn)
  |> result.map(fn(_) {
    sqlight.query(
      sql,
      ctx.conn,
      [sqlight.text(lobby.id), sqlight.text(lobby.name), sqlight.int(now)],
      decode.dynamic,
    )
  })
  |> result.map(fn(_) {
    let seat_values =
      lobby.seats
      |> list.flat_map(fn(s) {
        [
          sqlight.text(s.id),
          sqlight.nullable(sqlight.text, s.name),
          sqlight.text(lobby.id),
          sqlight.int(now),
        ]
      })
    let seat_query_text =
      lobby.seats
      |> list.map(fn(_) { "(?, ?, ?, ?)" })
      |> string.join(",")

    let sql2 = "
      INSERT INTO seats (id, name, lobby_id, created_at)
      VALUES " <> seat_query_text <> ";"
    sqlight.query(sql2, ctx.conn, seat_values, decode.dynamic)
  })
  |> result.map(fn(_) {
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
            sqlight.int(now),
          ]
        })
      })

    let clock_query_text =
      lobby.seats
      |> list.map(fn(_) { "(?, ?, ?, ?)" })
      |> string.join(",")

    let sql3 = "
      INSERT INTO clock_events (seat_id, event_type, event_data, created_at)
      VALUES " <> clock_query_text <> ";"
    sqlight.query(sql3, ctx.conn, clock_values, decode.dynamic)
  })
  |> result.map(fn(_) { sqlight.exec("COMMIT TRANSACTION;", ctx.conn) })
}

pub fn get_lobby(lobby_id, ctx: Context) {
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
  |> result.map(fn(res) {
    echo res
    res
    |> list.fold(None, fn(current: Option(lobby.Lobby), item) {
      case current {
        None -> {
          Some(
            lobby.Lobby(id: item.lobby_id, name: item.lobby_name, seats: [
              lobby.Seat(id: item.seat_id, name: item.seat_name, clock: [
                item.clock_event,
              ]),
            ]),
          )
        }
        Some(l) -> {
          let new_seats =
            list.map(l.seats, fn(s) {
              case s.id == item.seat_id {
                True ->
                  lobby.Seat(id: s.id, name: s.name, clock: [
                    item.clock_event,
                    ..s.clock
                  ])
                False ->
                  lobby.Seat(id: item.seat_id, name: item.seat_name, clock: [
                    item.clock_event,
                  ])
              }
            })

          Some(lobby.Lobby(id: l.id, name: l.name, seats: new_seats))
        }
      }
    })
  })
  |> result.map(fn(l) { option.to_result(l, NotFoundErr) })
  |> result.flatten
}

type GetLobbyResult {
  GetLobbyResult(
    lobby_id: String,
    lobby_name: String,
    seat_id: String,
    seat_name: Option(String),
    clock_event: clock.ClockEvent,
  )
}

fn lobby_decoder() {
  use event_type <- decode.field(4, decode.string)
  use event_data <- decode.field(5, decode.optional(decode.string))
  use event_time_num <- decode.field(6, decode.int)

  let clock_event = {
    let event_time = timestamp.from_unix_seconds(event_time_num)
    case event_type {
      "Start" -> clock.Start(event_time)
      "Stop" -> clock.Stop(event_time)
      "Add" -> {
        let millies =
          event_data
          |> option.map(float.parse)
          |> option.unwrap(Error(Nil))
          |> result.unwrap(0.0)
          |> float.multiply(1000.0)
          |> float.truncate

        clock.Add(event_time, duration.milliseconds(millies))
      }
      _ -> clock.Add(event_time, duration.seconds(0))
    }
  }

  use lobby_id <- decode.field(0, decode.string)
  use lobby_name <- decode.field(1, decode.string)
  use seat_id <- decode.field(2, decode.string)
  use seat_name <- decode.field(3, decode.optional(decode.string))

  decode.success(GetLobbyResult(
    lobby_id:,
    lobby_name:,
    seat_id:,
    seat_name:,
    clock_event:,
  ))
}
