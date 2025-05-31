import api/middleware
import api/models
import api/utils
import clock/clock
import db/db
import gleam/erlang/process
import gleam/http.{Get, Post}
import gleam/json
import gleam/list
import gleam/option.{None, Some}
import gleam/time/duration
import gleam/time/timestamp
import lobby/lobby
import lobby/messaging
import wisp.{type Request, type Response}

pub type Context {
  Context(db: db.Context, ws_hub: process.Subject(messaging.ChannelRequest))
}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- middleware.initial(req)

  // Wisp doesn't have a special router abstraction, instead we recommend using
  // regular old pattern matching. This is faster than a router, is type safe,
  // and means you don't have to learn or be limited by a special DSL.
  //
  case wisp.path_segments(req) {
    // This matches `/`.
    // [] -> home_page(req)
    // Create a lobby
    ["api", "v1", "lobby"] -> create_lobby(req, ctx)
    ["api", "v1", "lobby", lobby_id] -> get_lobby(req, lobby_id, ctx)
    ["api", "v1", "lobby", lobby_id, "advance", seat_id] ->
      advance_lobby(req, lobby_id, seat_id, ctx)
    ["api", "v1", "lobby", lobby_id, "start"] -> start_lobby(req, lobby_id, ctx)
    // This matches all other paths.
    _ -> wisp.not_found()
  }
}

fn start_lobby(req: Request, lobby_id, ctx) {
  use <- wisp.require_method(req, Post)
  use lobby <- require_lobby(lobby_id, ctx)
  // TODO: Require the requestor is allowed to start the lobby (Maybe store the session_id of the creator?)
  case lobby.start_lobby(lobby) {
    Ok(#(lobby, seat_updates)) -> {
      use _ <- require_success(fn() { db.insert_events(seat_updates, ctx.db) })

      let api_lobby =
        map_lobby_to_response(lobby)
        |> models.encode_get_lobby_response

      // Emit the new updated lobby to all websockets
      process.send(
        ctx.ws_hub,
        messaging.Emit(
          lobby_id,
          messaging.LobbyMessage("lobby_update", api_lobby),
        ),
      )

      let json_str =
        api_lobby
        |> json.to_string_tree

      wisp.ok()
      |> wisp.json_body(json_str)
    }
    Error(e) ->
      case e {
        lobby.LobbyIsActive ->
          Some("lobby is already started") |> utils.bad_request()
      }
  }
}

/// Create's a lobby
fn create_lobby(req, ctx: Context) {
  use <- wisp.require_method(req, Post)
  use body <- utils.require_json(req)

  // Decode the lobby request into a model
  case models.decode_create_lobby_request(body) {
    Ok(model) -> {
      // TODO: Can we do this validation in the decoder? Whats the right layer?
      // Some additional validation
      use <- utils.require_predicate(
        fn() { list.length(model.seats) >= 1 },
        "please specify at least one seat",
      )

      // Map this request model to a lobby.Lobby
      let lobby = map_create_request_to_lobby(model)

      // Save B)
      case db.save_lobby(lobby, ctx.db) {
        Ok(_) -> {
          // Success! Return the id
          let response = models.CreateLobbyResponse(lobby.id)
          wisp.ok()
          |> wisp.json_body(models.encode_create_lobby_response(response))
        }
        Error(e) -> {
          echo e

          wisp.internal_server_error()
        }
      }
    }
    Error(errors) -> {
      let err_body = models.encode_unprocessable_entity_response(errors)

      wisp.unprocessable_entity()
      |> wisp.json_body(err_body)
    }
  }
}

fn get_lobby(req, lobby_id, ctx: Context) {
  use <- wisp.require_method(req, Get)
  use dblobby <- require_lobby(lobby_id, ctx)
  let json_str =
    map_lobby_to_response(dblobby)
    |> models.encode_get_lobby_response
    |> json.to_string_tree

  wisp.ok()
  |> wisp.json_body(json_str)
}

/// Advances the lobby. Only works if the seat_id responsible is currently in a position to advance the table. IE, is the current active seat
fn advance_lobby(req, lobby_id, seat_id, ctx) {
  use <- wisp.require_method(req, Post)
  use lobby <- require_lobby(lobby_id, ctx)
  use <- require_can_advance_lobby(lobby, seat_id)

  case lobby.advance(lobby) {
    Ok(#(lobby, seat_updates)) -> {
      // Persist the updates, or return error
      use _ <- require_success(fn() { db.insert_events(seat_updates, ctx.db) })

      let api_lobby =
        map_lobby_to_response(lobby)
        |> models.encode_get_lobby_response

      // Emit the new updated lobby to all websockets
      process.send(
        ctx.ws_hub,
        messaging.Emit(
          lobby_id,
          messaging.LobbyMessage("lobby_update", api_lobby),
        ),
      )

      wisp.ok()
      |> wisp.json_body(json.to_string_tree(api_lobby))
    }
    Error(e) -> {
      case e {
        lobby.NoActiveSeat ->
          Some("lobby has not been started") |> utils.bad_request()
        lobby.MultipleActiveSeats ->
          Some(
            "lobby somehow has multiple seats active! this is an invalid state",
          )
          |> utils.bad_request()
      }
    }
  }
}

fn require_lobby(lobby_id, ctx: Context, callback) {
  case db.get_lobby(lobby_id, ctx.db) {
    Ok(dblobby) -> callback(dblobby)
    Error(e) if e == db.NotFoundErr -> {
      echo e
      wisp.not_found()
    }
    Error(e) -> {
      echo e
      wisp.internal_server_error()
    }
  }
}

/// Requires that the requested seat is allowed to advance the lobby
/// Returns a 400 error if not
/// Or a 404 error if we cant find the seat
fn require_can_advance_lobby(lobby: lobby.Lobby, seat_id: String, callback) {
  case lobby.can_seat_advance_lobby(lobby.Clockwise, lobby, seat_id) {
    Ok(can_advance) ->
      case can_advance {
        True -> callback()
        False -> Some("seat is not active") |> utils.bad_request()
      }
    Error(e) ->
      case e {
        lobby.SeatNotFound -> wisp.not_found()
      }
  }
}

/// Executes the given function, and calls the callback with the result if succesfull
/// Otherwise logs the error and returns internal_server_error
fn require_success(func, callback) {
  case func() {
    Ok(result) -> callback(result)
    Error(e) -> {
      echo e
      wisp.internal_server_error()
    }
  }
}

fn map_create_request_to_lobby(model: models.CreateLobbyRequest) {
  let seats =
    model.seats
    |> list.map(fn(s) {
      let #(new_clock, _) =
        clock.add_time([], duration.seconds(s.initial_seconds))

      lobby.Seat(
        id: lobby.generate_id(lobby.SeatId),
        name: s.name,
        clock: new_clock,
      )
    })

  lobby.Lobby(id: lobby.generate_id(lobby.LobbyId), name: model.name, seats:)
}

fn map_lobby_to_response(lobby: lobby.Lobby) -> models.GetLobbyResponse {
  let seats =
    lobby.seats
    |> list.map(fn(s) {
      // To map the DB lobby to the response, we need to compute two things:
      //   - The remaining duration of each clock
      //   - If the clock is running, what time the clock will end

      // With the seat's clock events, figure out the current clock state
      let clock_state = clock.check_clock(s.clock)

      let ends_at = {
        // If active since is None, that means the clock is not running,
        // and there is no ends_at value to be calculated.
        case option.is_none(clock_state.active_since) {
          True -> None
          False ->
            timestamp.add(
              timestamp.system_time(),
              clock_state.remaining_duration,
            )
            |> Some
        }
      }

      // Finally map that clock back into a LobbyClock, and map the result into a LobbySeat
      models.LobbyClock(
        remaining_duration: clock_state.remaining_duration,
        ends_at:,
      )
      |> models.LobbySeat(id: s.id, name: s.name, clock: _)
    })

  let next_up = lobby.next_up(lobby)
  models.GetLobbyResponse(id: lobby.id, name: lobby.name, seats:, next_up:)
}
