import GameRoom from "./components/pages/GameRoom";
import { createBrowserRouter, RouterProvider } from "react-router-dom";
import Lobby from "./components/pages/Lobby";

export default function App() {
  return <RouterProvider router={router} />;
}

const router = createBrowserRouter([
  { path: "/", element: <Lobby /> },
  { path: "/room/:roomId", element: <GameRoom /> },
]);
