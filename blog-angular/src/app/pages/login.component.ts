import { Component, inject, signal } from "@angular/core";
import { FormsModule } from "@angular/forms";
import { Router } from "@angular/router";
import { AuthService } from "../auth.service";
import { errorMessage } from "../models";

@Component({
  selector: "app-login",
  standalone: true,
  imports: [FormsModule],
  template: `
    <div class="mx-auto max-w-sm">
      <h1 class="text-2xl font-semibold tracking-tight">Log in</h1>
      <form (ngSubmit)="submit()" class="mt-6 space-y-4">
        <label class="block">
          <span class="text-sm text-zinc-600 dark:text-zinc-400">Email</span>
          <input
            type="email"
            name="email"
            required
            [(ngModel)]="email"
            autocomplete="email"
            class="mt-1 w-full rounded-lg border border-zinc-300 dark:border-zinc-700 bg-transparent px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent"
          />
        </label>
        <label class="block">
          <span class="text-sm text-zinc-600 dark:text-zinc-400">Password</span>
          <input
            type="password"
            name="password"
            required
            [(ngModel)]="password"
            autocomplete="current-password"
            class="mt-1 w-full rounded-lg border border-zinc-300 dark:border-zinc-700 bg-transparent px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent"
          />
        </label>
        @if (error()) {
          <p class="text-sm text-red-500">{{ error() }}</p>
        }
        <button
          type="submit"
          [disabled]="busy()"
          class="w-full rounded-lg bg-violet-600 hover:bg-violet-500 disabled:opacity-50 px-4 py-2 text-sm font-medium text-white transition-colors"
        >
          {{ busy() ? "Signing in…" : "Sign in" }}
        </button>
      </form>
    </div>
  `,
})
export class LoginComponent {
  private auth = inject(AuthService);
  private router = inject(Router);

  email = "";
  password = "";
  readonly busy = signal(false);
  readonly error = signal<string | null>(null);

  async submit(): Promise<void> {
    this.busy.set(true);
    this.error.set(null);
    try {
      await this.auth.login(this.email, this.password);
      await this.router.navigateByUrl("/");
    } catch (e) {
      this.error.set(errorMessage(e));
    } finally {
      this.busy.set(false);
    }
  }
}
