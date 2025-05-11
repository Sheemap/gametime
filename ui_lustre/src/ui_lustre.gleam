import api/models
import gleam/dynamic/decode
import gleam/http
import gleam/http/request
import gleam/int
import gleam/json
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/result
import lustre
import lustre/attribute
import lustre/effect.{type Effect}
import lustre/element.{type Element}
import lustre/element/html
import lustre/element/keyed

import lustre/event
import rsvp

// MAIN ------------------------------------------------------------------------

pub fn main() {
  let create_lobby = CreateLobbyModel(name: "Lobby Name", seats: [])
  let model = Model(active_lobby: None, create_lobby:)

  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", model)

  Nil
}

// MODEL -----------------------------------------------------------------------

type Model {
  Model(active_lobby: Option(Lobby), create_lobby: CreateLobbyModel)
}

type Lobby {
  Lobby(id: String, name: String)
}

type CreateLobbyModel {
  CreateLobbyModel(name: String, seats: List(models.Seat))
}

fn init(model: Model) -> #(Model, Effect(Msg)) {
  // Calling the `tick` effect immediately on init kicks off our clock!
  #(model, effect.none())
}

// UPDATE ----------------------------------------------------------------------

type Msg {
  UserClickedAddClock
  UserClickedPrintState
  UserClickedCreateLobby
  UserChangedSeatName(Int, String)
  UserChangedSeatInitialSeconds(Int, String)
  ApiCreatedLobby(Result(String, rsvp.Error))
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
      let new_name = case name {
        "" -> None
        _ -> Some(name)
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
              active_lobby: Some(Lobby(
                id: lobby_id,
                name: model.create_lobby.name,
              )),
              create_lobby: CreateLobbyModel("", []),
            )

          #(new_model, effect.none())
        }
      }
    }
    UserClickedCreateLobby -> {
      let effect = create_lobby(model.create_lobby, ApiCreatedLobby)
      #(model, effect)
    }
  }
}

fn create_lobby(
  lobby lobby: CreateLobbyModel,
  on_response handle_response: fn(Result(String, rsvp.Error)) -> msg,
  // Just like the `Element` type, the `Effect` type is parametrised by the type
  // of messages it produces. This is how we know messages we get back from an
  // effect are type-safe and can be handled by the `update` function.
) -> Effect(msg) {
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

// VIEW ------------------------------------------------------------------------

fn view(model: Model) -> Element(Msg) {
  let current_id = case model.active_lobby {
    None -> "None"
    Some(l) -> l.id
  }

  html.div(
    [attribute.class("w-screen h-screen flex justify-center items-center")],
    [
      html.div([], [html.p([], [html.text("Current Lobby ID: " <> current_id)])]),
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
