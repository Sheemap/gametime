import gleam/dynamic/decode
import pog

/// A row you get from running the `get_room_clocks_by_clock_id` query
/// defined in `./src/gametime/sql/get_room_clocks_by_clock_id.sql`.
///
/// > 🐿️ This type definition was generated automatically using v2.1.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetRoomClocksByClockIdRow {
  GetRoomClocksByClockIdRow(
    id: String,
    room_id: String,
    label: String,
    position: Int,
    increment: Int,
    initial_value: Int,
    state: ClockEventType,
    remaining_time: Int,
    updated_at: Float,
  )
}

/// Given a clock ID, get all the clocks in the same room with their current states
///
/// > 🐿️ This function was generated automatically using v2.1.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_room_clocks_by_clock_id(db, arg_1) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use room_id <- decode.field(1, decode.string)
    use label <- decode.field(2, decode.string)
    use position <- decode.field(3, decode.int)
    use increment <- decode.field(4, decode.int)
    use initial_value <- decode.field(5, decode.int)
    use state <- decode.field(6, clock_event_type_decoder())
    use remaining_time <- decode.field(7, decode.int)
    use updated_at <- decode.field(8, decode.float)
    decode.success(
      GetRoomClocksByClockIdRow(
        id:,
        room_id:,
        label:,
        position:,
        increment:,
        initial_value:,
        state:,
        remaining_time:,
        updated_at:,
      ),
    )
  }

  let query = "-- Given a clock ID, get all the clocks in the same room with their current states
select
	c.id,
    c.room_id,
	c.label,
    c.position,
	c.increment,
	c.initial_value,
	coalesce (latest_state.event_type, 'STOP') as state,
	coalesce (latest_event.remaining_time, c.initial_value) as remaining_time,
    -- Updated at in milliseconds
    (extract(epoch from coalesce (latest_event.timestamp, CURRENT_TIMESTAMP at time zone 'UTC')) * 1000) as updated_at
from
	public.clocks c
cross join (
	select
		r.id
	from
		public.rooms r
	inner join
		public.clocks c on c.room_id = r.id and c.id = $1
) as r
left join (
	select
		ce.clock_id,
		ce.event_type
	from
		public.clock_events ce
	join public.clocks c on
		ce.clock_id = c.id
		and ce.event_type in ('START', 'STOP')
	order by
		ce.timestamp desc
	limit 1
   ) latest_state on
	c.id = latest_state.clock_id
left join (
	select
		ce.timestamp,
		ce.clock_id,
		ce.event_type,
		ce.remaining_time
	from
		public.clock_events ce
	join public.clocks c on
		ce.clock_id = c.id
	order by
		ce.timestamp desc
	limit 1
   ) latest_event on
	c.id = latest_event.clock_id
where
   c.room_id = r.id
"

  pog.query(query)
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Runs the `insert_clock_event` query
/// defined in `./src/gametime/sql/insert_clock_event.sql`.
///
/// > 🐿️ This function was generated automatically using v2.1.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn insert_clock_event(db, arg_1, arg_2, arg_3) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  let query = "insert into public.clock_events (timestamp, clock_id, event_type, remaining_time)
values (CURRENT_TIMESTAMP at time zone 'UTC', $1, $2, $3)


"

  pog.query(query)
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(clock_event_type_encoder(arg_2))
  |> pog.parameter(pog.int(arg_3))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// Inserts a new Room record
///
/// > 🐿️ This function was generated automatically using v2.1.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn new_room(db, arg_1) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  let query = "-- Inserts a new Room record
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
pub fn new_clock(db, arg_1, arg_2, arg_3, arg_4, arg_5, arg_6) {
  let decoder = decode.map(decode.dynamic, fn(_) { Nil })

  let query = "-- Inserts a clock
insert into clocks (id, room_id, label, position, increment, initial_value)
values ($1, $2, $3, $4, $5, $6)
"

  pog.query(query)
  |> pog.parameter(pog.text(arg_1))
  |> pog.parameter(pog.text(arg_2))
  |> pog.parameter(pog.text(arg_3))
  |> pog.parameter(pog.int(arg_4))
  |> pog.parameter(pog.int(arg_5))
  |> pog.parameter(pog.int(arg_6))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

/// A row you get from running the `get_room_by_clock` query
/// defined in `./src/gametime/sql/get_room_by_clock.sql`.
///
/// > 🐿️ This type definition was generated automatically using v2.1.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type GetRoomByClockRow {
  GetRoomByClockRow(id: String, clock_ids: List(String))
}

/// Gets a room with a clock ID
///
/// > 🐿️ This function was generated automatically using v2.1.0 of
/// > the [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub fn get_room_by_clock(db, arg_1) {
  let decoder = {
    use id <- decode.field(0, decode.string)
    use clock_ids <- decode.field(1, decode.list(decode.string))
    decode.success(GetRoomByClockRow(id:, clock_ids:))
  }

  let query = "-- Gets a room with a clock ID
select
  r.id, array_agg(c.id) as clock_ids
from
  rooms r
  join clocks c on c.room_id = r.id
where
  c.id = $1
group by
  r.id

"

  pog.query(query)
  |> pog.parameter(pog.text(arg_1))
  |> pog.returning(decoder)
  |> pog.execute(db)
}

// --- Enums -------------------------------------------------------------------

/// Corresponds to the Postgres `clock_event_type` enum.
///
/// > 🐿️ This type definition was generated automatically using v2.1.0 of the
/// > [squirrel package](https://github.com/giacomocavalieri/squirrel).
///
pub type ClockEventType {
  Stop
  Start
  Add
}

fn clock_event_type_decoder() {
  use variant <- decode.then(decode.string)
  case variant {
    "STOP" -> decode.success(Stop)
    "START" -> decode.success(Start)
    "ADD" -> decode.success(Add)
    _ -> decode.failure(Stop, "ClockEventType")
  }
}

fn clock_event_type_encoder(variant) {
  case variant {
    Stop -> "STOP"
    Start -> "START"
    Add -> "ADD"
  }
  |> pog.text
}
