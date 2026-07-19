import { useState } from "react"
import { Rocket } from "lucide-react"

import { Button } from "@/components/ui/button"
import {
  Card,
  CardContent,
  CardDescription,
  CardFooter,
  CardHeader,
  CardTitle,
} from "@/components/ui/card"
import { Input } from "@/components/ui/input"

export default function App() {
  const [email, setEmail] = useState("")
  const [subscribed, setSubscribed] = useState(false)

  return (
    <main className="flex min-h-screen flex-col items-center justify-center gap-8 px-6">
      <div className="flex flex-col items-center gap-2 text-center">
        <p className="rounded-full border bg-secondary px-3 py-1 text-xs font-medium text-muted-foreground">
          Vite &middot; React 19 &middot; Tailwind &middot; shadcn/ui
        </p>
        <h1 className="text-4xl font-bold tracking-tight">shadcn/ui, wired up</h1>
        <p className="max-w-md text-muted-foreground">
          Button, Card and Input are included. Add anything else with{" "}
          <code className="rounded bg-muted px-1.5 py-0.5 text-sm">
            bunx shadcn@latest add &lt;name&gt;
          </code>
        </p>
      </div>

      <Card className="w-full max-w-sm">
        <CardHeader>
          <CardTitle>Stay in the loop</CardTitle>
          <CardDescription>
            A little form to prove the components work.
          </CardDescription>
        </CardHeader>
        <CardContent>
          <Input
            type="email"
            placeholder="you@example.com"
            value={email}
            onChange={(e) => {
              setEmail(e.target.value)
              setSubscribed(false)
            }}
          />
        </CardContent>
        <CardFooter className="justify-between">
          <Button variant="ghost" size="sm" onClick={() => setEmail("")}>
            Clear
          </Button>
          <Button
            disabled={!email.includes("@")}
            onClick={() => setSubscribed(true)}
          >
            <Rocket /> {subscribed ? "Subscribed!" : "Subscribe"}
          </Button>
        </CardFooter>
      </Card>

      <div className="flex gap-2">
        <Button variant="secondary">Secondary</Button>
        <Button variant="outline">Outline</Button>
        <Button variant="destructive">Destructive</Button>
      </div>
    </main>
  )
}
