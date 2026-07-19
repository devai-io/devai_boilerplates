import { useState } from "react"

export default function App() {
  const [count, setCount] = useState(0)

  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-zinc-950 px-6 text-zinc-100">
      <p className="mb-4 rounded-full border border-zinc-800 bg-zinc-900 px-3 py-1 text-xs font-medium tracking-wide text-zinc-400">
        Vite &middot; React 19 &middot; TypeScript &middot; Tailwind
      </p>

      <h1 className="text-center text-4xl font-bold tracking-tight sm:text-5xl">
        Everything is{" "}
        <span className="bg-gradient-to-r from-violet-400 to-sky-400 bg-clip-text text-transparent">
          wired up
        </span>
      </h1>

      <p className="mt-4 max-w-md text-center text-zinc-400">
        Edit <code className="rounded bg-zinc-900 px-1.5 py-0.5 text-sm text-zinc-300">src/App.tsx</code>{" "}
        and save to see hot reload in action.
      </p>

      <button
        onClick={() => setCount((c) => c + 1)}
        className="mt-8 rounded-lg bg-violet-600 px-5 py-2.5 text-sm font-semibold text-white transition-colors hover:bg-violet-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-violet-400 active:bg-violet-700"
      >
        Count is {count}
      </button>
    </main>
  )
}
