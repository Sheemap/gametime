import birl/duration.{type Duration}
import envoy
import gametime/clients/client_manager.{type ClientManagementMessage}
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option}
import gleam/result
import pog
import sqlight.{type Connection}

pub type Context {
  Context(client_manager: Subject(ClientManagementMessage), db: pog.Connection)
}

fn init_pog() {
  use database_url <- result.try(envoy.get("DATABASE_URL"))
  use config <- result.try(pog.url_config(database_url))
  Ok(pog.connect(config))
}

pub fn init() -> Context {
  //use db <- sqlight.with_connection("file:data.db")
  //let assert Ok(db) = sqlight.open(":memory:")
  let assert Ok(db) = init_pog()
  let client_manager = client_manager.init()

  Context(client_manager, db)
}
