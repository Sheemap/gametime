import clock/clock
import db/db
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
import web/utils
import wisp.{type Request, type Response}

pub type Context {
  Context(db: db.Context)
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
    ["api", "v1", "lobby", lobby_id] -> lobby_resource(req, lobby_id, ctx)
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
    Ok(#(lobby, _events)) -> {
      // TODO: Insert all events

      let json_str =
        api_models.map_lobby_to_response(lobby)
        |> api_models.encode_get_lobby_response

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

fn lobby_resource(req: Request, lobby_id, ctx) {
  case req.method {
    Get -> get_lobby(req, lobby_id, ctx)
    _ -> wisp.not_found()
  }
}

/// Create's a lobby
fn create_lobby(req, ctx: Context) {
  use <- wisp.require_method(req, Post)
  use body <- wisp.require_json(req)

  // Decode the lobby request into a model
  case api_models.decode_create_lobby_request(body) {
    Ok(model) -> {
      // TODO: Can we do this validation in the decoder? Whats the right layer?
      // Some additional validation
      use <- middleware.require_predicate(
        fn() { list.length(model.seats) >= 1 },
        "please specify at least one seat",
      )

      // Map this request model to a lobby.Lobby
      let lobby = api_models.map_create_request_to_lobby(model)

      // Save B)
      case db.save_lobby(lobby, ctx.db) {
        Ok(_) -> {
          // Success! Return the id
          let response = api_models.CreateLobbyResponse(lobby.id)
          wisp.ok()
          |> wisp.json_body(api_models.encode_create_lobby_response(response))
        }
        Error(e) -> {
          echo e

          wisp.internal_server_error()
        }
      }
    }
    Error(errors) -> {
      let err_body = api_models.encode_unprocessable_entity_response(errors)

      wisp.unprocessable_entity()
      |> wisp.json_body(err_body)
    }
  }
}

fn get_lobby(_req, lobby_id, ctx: Context) {
  use dblobby <- require_lobby(lobby_id, ctx)
  let json_str =
    api_models.map_lobby_to_response(dblobby)
    |> api_models.encode_get_lobby_response

  wisp.ok()
  |> wisp.json_body(json_str)
}

/// Advances the lobby. Only works if the seat_id resonsible is currently in a position to advance the table. IE, is the current active seat
fn advance_lobby(req, lobby_id, seat_id, ctx) {
  use <- wisp.require_method(req, Post)
  use lobby <- require_lobby(lobby_id, ctx)
  use <- require_can_advance_lobby(lobby, seat_id)

  case lobby.advance(lobby) {
    Ok(lobby_update) -> {
      let api_lobby = api_models.map_lobby_to_response(lobby_update.0)

      wisp.ok()
      |> wisp.json_body(api_models.encode_get_lobby_response(api_lobby))
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
