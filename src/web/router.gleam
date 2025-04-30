import clock/clock
import gleam/dynamic
import gleam/dynamic/decode
import gleam/http.{Delete, Get, Post, Put}
import gleam/http/request
import gleam/http/response
import gleam/io
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/result
import gleam/string_tree
import gleam/time/duration
import gleam/time/timestamp
import lobby/lobby
import web/api_models
import web/json_decoders
import web/middleware
import wisp.{type Request, type Response}

pub fn handle_request(req: Request) -> Response {
  use req <- middleware.initial(req)

  // Wisp doesn't have a special router abstraction, instead we recommend using
  // regular old pattern matching. This is faster than a router, is type safe,
  // and means you don't have to learn or be limited by a special DSL.
  //
  case wisp.path_segments(req) {
    // This matches `/`.
    // [] -> home_page(req)
    // This matches `/todos`.
    // ["todos"] -> todos(req)
    // This matches `/todos/:id`.
    // The `id` segment is bound to a variable and passed to the handler.
    // ["todos", id] -> handle_todo(req, id)
    // Create a lobby
    ["api", "v1", "lobby"] -> create_lobby(req)
    ["api", "v1", "lobby", lobby_id] -> lobby_resource(req, lobby_id)
    ["api", "v1", "lobby", lobby_id, "advance", seat_id] ->
      advance_lobby(req, lobby_id, seat_id)
    // This matches all other paths.
    _ -> wisp.not_found()
  }
}

fn lobby_resource(req: Request, lobby_id) {
  case req.method {
    Get -> get_lobby(req, lobby_id)
    _ -> wisp.not_found()
  }
}

/// Create's a lobby
fn create_lobby(req) {
  use <- wisp.require_method(req, Post)
  use body <- wisp.require_json(req)

  case api_models.decode_create_lobby_request(body) {
    Ok(model) -> {
      // TODO: Do the logic to create the lobby and gen an ID
      let response = api_models.CreateLobbyResponse("lobby_id_here")

      wisp.ok()
      |> wisp.json_body(api_models.encode_create_lobby_response(response))
    }
    Error(errors) -> {
      let err_body = api_models.encode_unprocessable_entity_response(errors)

      wisp.unprocessable_entity()
      |> wisp.json_body(err_body)
    }
  }
}

fn get_lobby(req, lobby_id) {
  // TODO: Actually retrieve the lobby
  let resp =
    api_models.GetLobbyResponse(
      id: lobby_id,
      name: "gamer lobby for gamer",
      seats: [
        api_models.LobbySeat(
          id: "whoa",
          name: None,
          clock: api_models.LobbyClock(
            remaining_duration: duration.seconds(30),
            ends_at: None,
          ),
        ),
        api_models.LobbySeat(
          id: "whosthat",
          name: Some("malcolm"),
          clock: api_models.LobbyClock(
            remaining_duration: duration.seconds(24),
            ends_at: Some(timestamp.add(
              timestamp.system_time(),
              duration.seconds(24),
            )),
          ),
        ),
      ],
    )
    |> api_models.encode_get_lobby_response

  wisp.ok()
  |> wisp.json_body(resp)
}

/// Advances the lobby. Only works if the seat_id resonsible is currently in a position to advance the table. IE, is the current active seat
fn advance_lobby(req, lobby_id, seat_id) {
  use <- wisp.require_method(req, Post)

  // TODO: Load lobby from DB
  let lobby =
    lobby.Lobby(id: lobby_id, name: "Hia", seats: [
      lobby.Seat(
        id: "buh",
        name: None,
        clock: clock.add_time(clock.start_clock([]), duration.seconds(60)),
      ),
      lobby.Seat(
        id: "iddkkkkk",
        name: None,
        clock: clock.add_time([], duration.seconds(60)),
      ),
    ])
  let seat = lobby.seats |> list.find(fn(s) { s.id == seat_id })

  case seat {
    Ok(s) -> {
      // TODO: Instead of hardcoded just checking the clock is active, maybe we have a function to determine if allowed? Taking into account lobby strategy
      let clock_state = clock.check_clock(s.clock)

      case clock_state.active_since {
        Some(_) -> {
          case lobby.advance(lobby) {
            Ok(l) -> {
              let api_lobby = api_models.map_lobby_to_response(l)

              wisp.ok()
              |> wisp.json_body(api_models.encode_get_lobby_response(api_lobby))
            }
            Error(_) -> wisp.bad_request()
          }
        }
        None -> wisp.bad_request()
      }
    }
    Error(_) -> wisp.not_found()
  }
}
