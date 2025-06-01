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
import { Tooltip, TooltipContent, TooltipTrigger } from "../ui/tooltip";
import { CircleHelpIcon } from "lucide-react";

type Seat = {
  name: string;
  initial_hours: number;
  initial_minutes: number;
  initial_seconds: number;
};

export default function () {
  const [players, setPlayers] = useState<Seat[]>([]);
  const [roomName, setRoomName] = useState("");
  const [isDialogOpen, setIsDialogOpen] = useState(false);
  const [editingPlayerIndex, setEditingPlayerIndex] = useState<number | null>(null);
  const [dialogMode, setDialogMode] = useState<'add' | 'edit'>('add');
  const [dialogFormKey, setDialogFormKey] = useState(0); // Force form reset

  const handleAddPlayer = () => {
    setEditingPlayerIndex(null);
    setDialogMode('add');
    setDialogFormKey(prev => prev + 1);
    setIsDialogOpen(true);
  };

  const handleEditPlayer = (index: number) => {
    setEditingPlayerIndex(index);
    setDialogMode('edit');
    setDialogFormKey(prev => prev + 1);
    setIsDialogOpen(true);
  };

  const handleDeletePlayer = (index: number) => {
    setPlayers(players.filter((_, i) => i !== index));
  };

  const handleFormSubmit = (e: React.FormEvent<HTMLFormElement>) => {
    e.preventDefault();
    const form = e.currentTarget;
    const nameInput = form.elements.namedItem("name") as HTMLInputElement;
    const hoursInput = form.elements.namedItem("hours") as HTMLInputElement;
    const minutesInput = form.elements.namedItem("minutes") as HTMLInputElement;
    const secondsInput = form.elements.namedItem("seconds") as HTMLInputElement;

    if (nameInput.value && hoursInput.value && minutesInput.value && secondsInput.value) {
      const newPlayer = {
        name: nameInput.value,
        initial_hours: parseInt(hoursInput.value),
        initial_minutes: parseInt(minutesInput.value),
        initial_seconds: parseInt(secondsInput.value),
      };

      if (editingPlayerIndex !== null) {
        // Edit existing player - close dialog after update
        const updatedPlayers = [...players];
        updatedPlayers[editingPlayerIndex] = newPlayer;
        setPlayers(updatedPlayers);
        setIsDialogOpen(false);
        setEditingPlayerIndex(null);
      } else {
        // Add new player - keep dialog open for adding more players
        setPlayers([...players, newPlayer]);
      }

      form.reset();
    }
  };

  const currentPlayer = editingPlayerIndex !== null ? players[editingPlayerIndex] : null;

  return (
    <div className="p-20">
      <h1 className="text-3xl my-2 font-semibold">Create a Game Room</h1>
      <Label htmlFor="roomName" className="font-medium">Room Name</Label>
      <Input
        id="roomName"
        type="text"
        placeholder="Name"
        value={roomName}
        onChange={(e) => setRoomName(e.target.value)}
      />
      
      <Dialog open={isDialogOpen} onOpenChange={setIsDialogOpen}>
        <DialogTrigger asChild>
          <Button className="my-4" onClick={handleAddPlayer}>
            Add a player
          </Button>
        </DialogTrigger>
        <DialogContent>
          <DialogHeader>
            <DialogTitle>
              {dialogMode === 'edit' ? "Edit Player" : "Add a Player"}
            </DialogTitle>
          </DialogHeader>
          <form
            key={dialogFormKey}
            className="grid gap-4"
            onSubmit={handleFormSubmit}
          >
            <div className="grid gap-3">
              <Label htmlFor="name-1" className="font-medium">Player Name</Label>
              <Input
                id="name-1"
                name="name"
                placeholder="Jack Hoffman"
                defaultValue={currentPlayer?.name || ""}
                required
                minLength={1}
              />
            </div>
            <Tooltip>
              <TooltipTrigger asChild>
                <div className="flex items-center gap-1 w-40">
                  <h2 className="leading-none font-medium">Total Clock Time</h2>
                  <CircleHelpIcon className="w-4 h-4" />
                </div>
              </TooltipTrigger>
              <TooltipContent>
                <p>
                  The total amount of time the player has to spend on their
                  turns throughout the full game.
                </p>
              </TooltipContent>
            </Tooltip>
            <div className="flex flex-col md:flex-row gap-3">
              <div className="flex-1">
                <Label htmlFor="hours-1">Total Hours</Label>
                <Input
                  id="hours-1"
                  name="hours"
                  type="number"
                  min={0}
                  defaultValue={currentPlayer?.initial_hours?.toString() || "0"}
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
                  defaultValue={currentPlayer?.initial_minutes?.toString() || ""}
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
                  defaultValue={currentPlayer?.initial_seconds?.toString() || ""}
                  required
                />
              </div>
            </div>
            <Button type="submit" className="mt-4">
              {dialogMode === 'edit' ? "Update Player" : "Add Player"}
            </Button>
          </form>
        </DialogContent>
      </Dialog>
      
      {players.length > 0 && (
        <PlayerTable 
          players={players} 
          onEditPlayer={handleEditPlayer}
          onDeletePlayer={handleDeletePlayer}
        />
      )}
      {players.length > 0 && roomName !== "" && (
        <Button>Create Game Room</Button>
      )}
    </div>
  );
}

function PlayerTable({ 
  players, 
  onEditPlayer, 
  onDeletePlayer 
}: { 
  players: Seat[];
  onEditPlayer: (index: number) => void;
  onDeletePlayer: (index: number) => void;
}) {
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
              <Button 
                className="mr-2" 
                onClick={() => onEditPlayer(idx)}
              >
                Edit
              </Button>
              <Button 
                variant="destructive"
                onClick={() => onDeletePlayer(idx)}
              >
                Delete
              </Button>
            </TableCell>
          </TableRow>
        ))}
      </TableBody>
    </Table>
  );
}