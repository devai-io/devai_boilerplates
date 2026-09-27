import { Component, inject } from "@angular/core";
import { Router, RouterLink, RouterOutlet } from "@angular/router";
import { Auth } from "./auth";

@Component({
  selector: "app-root",
  imports: [RouterOutlet, RouterLink],
  template: `
    <div class="min-h-screen bg-white dark:bg-zinc-950 text-zinc-900 dark:text-zinc-100 antialiased">
      <header class="border-b border-zinc-200 dark:border-zinc-800">
        <div class="mx-auto max-w-2xl px-6 py-5 flex items-center justify-between">
          <a routerLink="/" class="font-semibold tracking-tight">blog</a>
          <nav class="flex items-center gap-4 text-sm text-zinc-500 dark:text-zinc-400">
            @if (auth.authed()) {
              <a routerLink="/write" class="hover:text-zinc-900 dark:hover:text-zinc-100">Write</a>
              <button (click)="logout()" class="hover:text-zinc-900 dark:hover:text-zinc-100">
                Log out
              </button>
            } @else {
              <a routerLink="/login" class="hover:text-zinc-900 dark:hover:text-zinc-100">Log in</a>
            }
          </nav>
        </div>
      </header>
      <main class="mx-auto max-w-2xl px-6 py-10">
        <router-outlet />
      </main>
    </div>
  `,
})
export class App {
  protected readonly auth = inject(Auth);
  private readonly router = inject(Router);

  logout(): void {
    this.auth.logout();
    void this.router.navigateByUrl("/");
  }
}
