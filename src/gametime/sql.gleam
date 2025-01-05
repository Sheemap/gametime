import gleam/dynamic/decode
import pog

/// Inserts a new Room record
///
/// > 🐿️ This function was generated automatically using v2.1.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn new_room(db, arg_1) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  let query =
    "-- Inserts a new Room record
insert into rooms (id)
values ($1)
"

  pog.query(query)
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Inserts a clock
///
/// > 🐿️ This function was generated automatically using v2.1.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn new_clock(db, arg_1, arg_2, arg_3, arg_4, arg_5) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  let query =
    "-- Inserts a clock
insert into clocks (id, room_id, label, increment, initial_value)
values ($1, $2, $3, $4, $5)
"

  pog.query(query)
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.int(arg_4))
  |> pog.parameter(pog.int(arg_5))
  |> pog.returning(decoder)
  |> pog.execute(db)
}
