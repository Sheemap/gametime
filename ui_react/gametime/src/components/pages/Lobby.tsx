import { Label } from "@radix-ui/react-label";
import { Input } from "../ui/input";
import { Button } from "../ui/button";
import {
  Table,
  TableCaption,
  TableHead,
  TableHeader,
  TableRow,
} from "../ui/table";
import { useState } from "react";
import { Dialog, DialogTrigger } from "@radix-ui/react-dialog";
import { DialogContent, DialogHeader, DialogTitle } from "../ui/dialog";

type Seat = {
  name: string;
  initial_seconds: number;
};

export default function () {
  const [players, setPlayers] = useState<Seat[]>([]);

  return (
    <div className="p-20">
      <h1 className="text-3xl my-2">Create a room</h1>
      <Label htmlFor="roomName">Room Name</Label>
      <Input id="roomName" type="text" placeholder="Name" />
      <Dialog>
        <DialogTrigger asChild>
          <Button className="my-4">Add a player</Button>
        </DialogTrigger>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>Add a player</DialogTitle>
          </DialogHeader>
          <form
            className="grid gap-4"
            // onSubmit logic to be added later
          >
            <div className="grid gap-3">
              <Label htmlFor="name-1">Name</Label>
              <Input
                id="name-1"
                name="name"
                placeholder="Jack Hoffman"
                required
                minLength={1}
              />
            </div>
            <h2>Total clock Seconds</h2>
            <h3 className="text-sm">
              The total amount of time the player has to spend on their turns
              throughout the full game.
            </h3>
            <div className="flex flex-col md:flex-row gap-3">
              <div className="flex-1">
                <Label htmlFor="hours-1">Total Hours</Label>
                <Input
                  id="hours-1"
                  name="hours"
                  type="number"
                  min={0}
                  defaultValue="0"
                  required
                />
              </div>
              <div className="flex-1">
                <Label htmlFor="minutes-1">Total Minutes</Label>
                <Input
                  id="minutes-1"
                  name="minutes"
                  type="number"
                  min={0}
                  max={59}
                  required
                />
              </div>
              <div className="flex-1">
                <Label htmlFor="seconds-1">Total Seconds</Label>
                <Input
                  id="seconds-1"
                  name="seconds"
                  type="number"
                  min={0}
                  max={59}
                  required
                />
              </div>
            </div>
            <Button
              type="submit"
              className="mt-4"
              onClick={(e) => {
                e.preventDefault();
                const form = e.currentTarget.form;
                if (form) {
                  const nameInput = form.elements.namedItem(
                    "name"
                  ) as HTMLInputElement;
                  const hoursInput = form.elements.namedItem(
                    "hours"
                  ) as HTMLInputElement;
                  const minutesInput = form.elements.namedItem(
                    "minutes"
                  ) as HTMLInputElement;
                  const secondsInput = form.elements.namedItem(
                    "seconds"
                  ) as HTMLInputElement;

                  if (
                    nameInput.value &&
                    hoursInput.value &&
                    minutesInput.value &&
                    secondsInput.value
                  ) {
                    const totalSeconds =
                      parseInt(hoursInput.value) * 3600 +
                      parseInt(minutesInput.value) * 60 +
                      parseInt(secondsInput.value);

                    setPlayers([
                      ...players,
                      {
                        name: nameInput.value,
                        initial_seconds: totalSeconds,
                      },
                    ]);
                    form.reset();
                  }
                }
              }}
            >
              Add Player
            </Button>
          </form>
        </DialogContent>
      </Dialog>
      {players.length > 0 && <PlayerTable players={players} />}
    </div>
  );
}

function PlayerTable({ players }: { players: Seat[] }) {
  return (
    <Table>
      <TableCaption>All players in your room</TableCaption>
      <TableHeader>
        <TableRow>
          <TableHead>Player Name</TableHead>
          <TableHead>Total Clock Time</TableHead>
          <TableHead>Player Controls</TableHead>
        </TableRow>
      </TableHeader>
      <tbody>
        {players.map((player, idx) => (
          <TableRow key={idx}>
            <TableHead>{player.name}</TableHead>
            <TableHead>{player.initial_seconds}</TableHead>
            <TableHead><Button>Edit</Button><Button variant="destructive">Delete</Button></TableHead>
          </TableRow>
        ))}
      </tbody>
    </Table>
  );
}
