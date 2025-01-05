import birl/duration.{type Duration}
import gametime/clients/client_manager.{type ClientManagementMessage}
import gleam/erlang/process.{type Subject}
import gleam/option.{type Option}
import sqlight.{type Connection}

pub type Context {
  Context(client_manager: Subject(ClientManagementMessage), db: Connection)
}

pub fn init() -> Context {
  //use db <- sqlight.with_connection("file:data.db")
  let assert Ok(db) = sqlight.open(":memory:")
  let client_manager = client_manager.init()

  let sql =
    "
  create table cats (name text, age int);

  insert into cats (name, age) values
  ('Nubi', 4),
  ('Biffy', 10),
  ('Ginny', 6);
  "
  let assert Ok(Nil) = sqlight.exec(sql, db)

  Context(client_manager, db)
}
