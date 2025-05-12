import api/models.{type GetLobbyResponse}
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import gleam/uri
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed
import modem

import lustre/event
import rsvp

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let create_lobby = CreateLobbyModel(name: "Lobby Name", seats: [])
  let model = Model(route: Index, active_lobby: None, create_lobby:)

  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", model)

  Nil
}

// MODEL -----------------------------------------------------------------------

type Model {
  Model(
    route: Route,
    active_lobby: Option(Lobby),
    create_lobby: CreateLobbyModel,
  )
}

type Lobby {
  Lobby(id: String, name: String)
}

type CreateLobbyModel {
  CreateLobbyModel(name: String, seats: List(models.Seat))
}

fn init(model: Model) -> #(Model, Effect(Msg)) {
  echo "init"
  let initial_route =
    modem.initial_uri()
    |> result.map(router)
    |> result.unwrap(model.route)

  let initial_effects =
    effect.batch([
      modem.init(on_route_change),
      load_route_data(model, initial_route),
    ])
  #(Model(..model, route: initial_route), initial_effects)
}

fn on_route_change(uri: uri.Uri) -> Msg {
  router(uri) |> RouteChanged
}

fn router(uri: uri.Uri) -> Route {
  case uri.path_segments(uri.path) {
    ["lobby", lobby_id] -> GameRoom(lobby_id)
    _ -> Index
  }
}

// UPDATE ----------------------------------------------------------------------

type Route {
  Index
  GameRoom(String)
}

type Msg {
  RouteChanged(Route)
  UserClickedLink(String)
  UserClickedAddClock
  UserClickedPrintState
  UserClickedCreateLobby
  UserChangedSeatName(Int, String)
  UserChangedSeatInitialSeconds(Int, String)
  ApiCreatedLobby(Result(String, rsvp.Error))
  ApiReturnedLobby(Result(models.GetLobbyResponse, rsvp.Error))
}

fn update(model: Model, msg: Msg) -> #(Model, Effect(Msg)) {
  case msg {
    UserClickedAddClock -> {
      let newseat = models.Seat(name: option.None, initial_seconds: 0)

      let newmodel =
        Model(
          ..model,
          create_lobby: CreateLobbyModel(..model.create_lobby, seats: [
            newseat,
            ..model.create_lobby.seats
          ]),
        )
      #(newmodel, effect.none())
    }
    UserChangedSeatName(s_index, name) -> {
      let trimmed = string.trim(name)
      let new_name = case string.is_empty(trimmed) {
        True -> None
        False -> Some(trimmed)
      }

      let seats =
        model.create_lobby.seats
        |> list.index_map(fn(s, i) {
          case i == s_index {
            True -> models.Seat(..s, name: new_name)
            False -> s
          }
        })
      let new_model =
        Model(
          ..model,
          create_lobby: CreateLobbyModel(..model.create_lobby, seats:),
        )

      #(new_model, effect.none())
    }
    UserClickedPrintState -> {
      echo model
      #(model, effect.none())
    }
    UserChangedSeatInitialSeconds(s_index, initial_seconds) -> {
      let initial_seconds = int.parse(initial_seconds) |> result.unwrap(-1)
      let seats =
        model.create_lobby.seats
        |> list.index_map(fn(s, i) {
          case i == s_index {
            True -> models.Seat(..s, initial_seconds:)
            False -> s
          }
        })
      let new_model =
        Model(
          ..model,
          create_lobby: CreateLobbyModel(..model.create_lobby, seats:),
        )

      #(new_model, effect.none())
    }
    ApiCreatedLobby(result) -> {
      case result {
        Error(_) -> {
          echo "UH oH!PROBLEM"
          #(model, effect.none())
        }
        Ok(lobby_id) -> {
          let new_model =
            Model(
              ..model,
              active_lobby: Some(Lobby(
                id: lobby_id,
                name: model.create_lobby.name,
              )),
              create_lobby: CreateLobbyModel(name: "", seats: []),
            )

          #(new_model, effect.none())
        }
      }
    }
    UserClickedCreateLobby -> {
      let effect = create_lobby(model.create_lobby, ApiCreatedLobby)
      #(model, effect)
    }
    RouteChanged(route) -> {
      echo "asdf"
      let effect = load_route_data(model, route)

      #(Model(..model, route:), effect)
    }
    UserClickedLink(path) -> #(model, modem.push(path, None, None))
    ApiReturnedLobby(resp) -> {
      case resp {
        Ok(lobby) -> {
          let active_lobby = Lobby(id: lobby.id, name: lobby.name) |> Some
          #(Model(..model, active_lobby:), effect.none())
        }
        Error(_) -> {
          #(model, effect.none())
        }
      }
    }
  }
}

fn load_route_data(model: Model, route: Route) -> Effect(Msg) {
  case route {
    GameRoom(lobby_id) -> load_room(model, lobby_id)
    _ -> effect.none()
  }
}

fn load_room(model: Model, lobby_id: String) -> Effect(Msg) {
  let lobby_has_data = model.active_lobby |> option.is_some
  let lobby_id_matches =
    model.active_lobby
    |> option.map(fn(lobby) { lobby.id == lobby_id })
    |> option.unwrap(False)

  // If we have lobby data, and the route matches, nothing to fetch!
  case lobby_has_data && lobby_id_matches {
    True -> effect.none()
    False -> get_lobby(lobby_id, ApiReturnedLobby)
  }
}

fn create_lobby(
  lobby: CreateLobbyModel,
  handle_response: fn(Result(String, rsvp.Error)) -> Msg,
) -> Effect(Msg) {
  let url = "http://127.0.0.1:8000/api/v1/lobby"

  let lobby_id_decoder = {
    use lobby_id <- decode.field("lobby_id", decode.string)
    decode.success(lobby_id)
  }
  let handler = rsvp.expect_json(lobby_id_decoder, handle_response)
  let body =
    json.object([
      #("name", json.string(lobby.name)),
      #(
        "seats",
        json.array(lobby.seats, fn(s) {
          json.object([
            #("name", json.nullable(s.name, json.string)),
            #("initial_seconds", json.int(s.initial_seconds)),
          ])
        }),
      ),
    ])

  case request.to(url) {
    Ok(request) ->
      request
      |> request.set_method(http.Post)
      |> request.set_header("content-type", "application/json")
      |> request.set_body(json.to_string(body))
      |> rsvp.send(handler)

    Error(_) -> panic as { "Failed to create request to " <> url }
  }
}

fn get_lobby(
  lobby_id: String,
  handle_response: fn(Result(GetLobbyResponse, rsvp.Error)) -> Msg,
) -> Effect(Msg) {
  let url = "http://127.0.0.1:8000/api/v1/lobby/" <> lobby_id

  let handler =
    rsvp.expect_json(models.get_lobby_response_decoder(), handle_response)

  case request.to(url) {
    Ok(request) ->
      request
      |> request.set_method(http.Get)
      |> rsvp.send(handler)

    Error(_) -> panic as { "Failed to create request to " <> url }
  }
}

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  case model.route {
    GameRoom(lobby_id) -> view_game_room(model, lobby_id)
    Index -> view_index(model)
  }
}

fn view_index(model: Model) -> Element(Msg) {
  let current_id = case model.active_lobby {
    None -> "None"
    Some(l) -> l.id
  }

  html.div(
    [attribute.class("w-screen h-screen flex justify-center items-center")],
    [
      html.div([], [
        html.p([], [
          html.text("Current Lobby ID: " <> current_id),
          html.button(
            [
              event.on_click(UserClickedLink("/lobby/" <> current_id)),
              attribute.disabled(model.active_lobby |> option.is_none),
            ],
            [html.text("Join the room!")],
          ),
        ]),
      ]),
      html.text("Hia :) Lets build you a lobby!"),
      html.button([event.on_click(UserClickedAddClock)], [
        html.text("Add a seat"),
      ]),
      html.button([event.on_click(UserClickedPrintState)], [
        html.text("Print current"),
      ]),
      keyed.ul(
        [],
        list.index_map(model.create_lobby.seats, fn(s, i) {
          #(
            int.to_string(i),
            html.div([], [
              html.input([
                event.on_change(UserChangedSeatName(i, _)),
                attribute.value(option.unwrap(s.name, "")),
              ]),
              html.input([
                event.on_change(UserChangedSeatInitialSeconds(i, _)),
                attribute.type_("number"),
                attribute.value(s.initial_seconds |> int.to_string),
              ]),
            ]),
          )
        }),
      ),
      html.button([event.on_click(UserClickedCreateLobby)], [
        html.text("Create Lobby!"),
      ]),
    ],
  )
}

fn view_game_room(model: Model, lobby_id: String) -> Element(Msg) {
  case model.active_lobby {
    None -> view_loading_game_room(model)
    Some(lobby) -> view_active_game_room(lobby)
  }
}

fn view_active_game_room(model: Lobby) -> Element(Msg) {
  html.div(
    [attribute.class("w-screen h-screen flex justify-center items-center")],
    [html.p([], [html.text("Name: "), html.text(model.name)])],
  )
}

fn view_loading_game_room(model: Model) -> Element(Msg) {
  html.div(
    [attribute.class("w-screen h-screen flex justify-center items-center")],
    [html.p([], [html.text("Waiting on your room :)")])],
  )
}
