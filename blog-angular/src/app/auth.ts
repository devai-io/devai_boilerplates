import { computed, inject, Injectable, signal } from "@angular/core";
import { HttpClient } from "@angular/common/http";
import { firstValueFrom } from "rxjs";

const TOKEN_KEY = "blog_token";

@Injectable({ providedIn: "root" })
export class Auth {
  private readonly http = inject(HttpClient);

  // The token lives in a signal; localStorage only rehydrates it across reloads.
  readonly token = signal<string | null>(localStorage.getItem(TOKEN_KEY));
  readonly authed = computed(() => this.token() !== null);

  async login(email: string, password: string): Promise<void> {
    const { token } = await firstValueFrom(
      this.http.post<{ token: string }>(`${NG_APP_API_URL}/auth/login`, { email, password }),
    );
    this.token.set(token);
    localStorage.setItem(TOKEN_KEY, token);
  }

  logout(): void {
    this.token.set(null);
    localStorage.removeItem(TOKEN_KEY);
  }
}
