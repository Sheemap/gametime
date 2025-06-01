import { Label } from "@radix-ui/react-label";
import { Input } from "../ui/input";
import { Button } from "../ui/button";
import {
  Table,
  TableBody,
  TableCaption,
  TableCell,
  TableHead,
  TableHeader,
  TableRow,
} from "../ui/table";
import { useState } from "react";
import { Dialog, DialogTrigger } from "@radix-ui/react-dialog";
import { DialogContent, DialogHeader, DialogTitle } from "../ui/dialog";
// API expects seconds but for the ease of logic for editing user time, just keep them separate until time to call API
type Seat = {
  name: string;
  initial_hours: number;
  initial_minutes: number;
  initial_seconds: number;
};

export default function () {
  const [players, setPlayers] = useState<Seat[]>([]);
  const [roomName, setRoomName] = useState("");

  return (
    <div className="p-20">
      <h1 className="text-3xl my-2">Create a room</h1>
      <Label htmlFor="roomName">Room Name</Label>
      <Input
        id="roomName"
        type="text"
        placeholder="Name"
        value={roomName}
        onChange={(e) => setRoomName(e.target.value)}
      />
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
            onSubmit={(e) => {
              e.preventDefault();
              const form = e.currentTarget;
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
                setPlayers([
                  ...players,
                  {
                    name: nameInput.value,
                    initial_hours: parseInt(hoursInput.value),
                    initial_minutes: parseInt(minutesInput.value),
                    initial_seconds: parseInt(secondsInput.value),
                  },
                ]);
                form.reset();
              }
            }}
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
            <Button type="submit" className="mt-4">
              Add Player
            </Button>
          </form>
        </DialogContent>
      </Dialog>
      {players.length > 0 && <PlayerTable players={players} />}
      {players.length > 0 && roomName != "" && (
        <Button>Create Game Room</Button>
      )}
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
      <TableBody>
        {players.map((player, idx) => (
          <TableRow key={idx}>
            <TableCell>{player.name}</TableCell>
            <TableCell>{`${player.initial_hours
              .toString()
              .padStart(2, "0")}:${player.initial_minutes
              .toString()
              .padStart(2, "0")}:${player.initial_seconds
              .toString()
              .padStart(2, "0")}`}</TableCell>
            <TableCell>
              <Button className="mr-2">Edit</Button>
              <Button variant="destructive">Delete</Button>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}
