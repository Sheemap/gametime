import Clock from "@/components/Clock";

export default function GameRoom() {
  const bgColor1 = "--pastel-bg-1";
  return (
    <div className="p-10 grid grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-6 gap-4 max-w-full">
      <div
        className={`clock bg-[var(${bgColor1})] text-secondary-foreground rounded-lg`}
      >
        <Clock />
      </div>
      <div className="clock bg-[var(--pastel-bg-2)] text-secondary-foreground rounded-lg">
        <Clock />
      </div>
      <div className="clock bg-[var(--pastel-bg-3)] text-secondary-foreground rounded-lg">
        <Clock />
      </div>
      <div className="clock bg-[var(--pastel-bg-4)] text-secondary-foreground rounded-lg">
        <Clock />
      </div>
      <div className="clock bg-[var(--pastel-bg-5)] text-secondary-foreground rounded-lg">
        <Clock />
      </div>
      <div className="clock bg-[var(--pastel-bg-6)] text-secondary-foreground rounded-lg">
        <Clock />
      </div>
      <div className="clock bg-[var(--pastel-bg-1)] text-secondary-foreground rounded-lg">
        <Clock />
      </div>
      <div className="clock bg-[var(--pastel-bg-2)] text-secondary-foreground rounded-lg">
        <Clock />
      </div>
      <div className="clock bg-[var(--pastel-bg-3)] text-secondary-foreground rounded-lg">
        <Clock />
      </div>
      <div className="clock bg-[var(--pastel-bg-4)] text-secondary-foreground rounded-lg">
        <Clock />
      </div>
      <div className="clock bg-[var(--pastel-bg-5)] text-secondary-foreground rounded-lg">
        <Clock />
      </div>
      <div className="clock bg-[var(--pastel-bg-6)] text-secondary-foreground rounded-lg">
        <Clock />
      </div>
    </div>
  );
}
