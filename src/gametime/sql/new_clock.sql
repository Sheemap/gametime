-- Inserts a clock
insert into clocks (id, room_id, label, increment, initial_value)
values ($1, $2, $3, $4, $5)
