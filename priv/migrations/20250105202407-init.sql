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
  increment integer NOT NULL,
  initial_value integer NOT NULL,

  CONSTRAINT clocks_pk PRIMARY KEY (id),
  CONSTRAINT fk_rooms FOREIGN KEY (room_id) REFERENCES rooms(id)
);

--- migration:down
drop table clocks;
drop table rooms;

--- migration:end
