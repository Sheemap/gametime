--- migration:up
create table rooms
(
  id varchar NOT NULL,

  CONSTRAINT rooms_pk PRIMARY KEY (id)
);

create table clocks
(
  id varchar NOT NULL,
  room_id varchar NOT NULL,
  label varchar NOT NULL,
  position integer NOT NULL,
  increment integer NOT NULL,
  initial_value integer NOT NULL,

  CONSTRAINT clocks_pk PRIMARY KEY (id),
  CONSTRAINT fk_rooms FOREIGN KEY (room_id) REFERENCES rooms(id)
);

create type clock_state as enum (
  'RUNNING',
  'STOPPED'
);
create type clock_event_type as enum (
  'ADD',
  'START',
  'STOP'
);
create table clock_events
(
  timestamp timestamp NOT NULL,
  clock_id varchar NOT NULL,
  event_type clock_event_type NOT NULL,
  remaining_time integer NOT NULL,
  details json NULL,

  CONSTRAINT fk_clocks FOREIGN KEY (clock_id) REFERENCES clocks(id)
);

--- migration:down
drop table clock_events;
drop table clocks;
drop table rooms;

--- migration:end
