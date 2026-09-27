import { Component, inject, input, OnInit, signal } from "@angular/core";
import { DatePipe } from "@angular/common";
import { Router, RouterLink } from "@angular/router";
import { Auth } from "../auth";
import { BlogApi } from "../blog-api";
import { Markdown } from "../markdown";
import { errorMessage, Post } from "../models";

@Component({
  selector: "app-post-detail",
  imports: [RouterLink, DatePipe, Markdown],
  template: `
    @if (error()) {
      <p class="text-red-500 text-sm">{{ error() }}</p>
    } @else if (post(); as post) {
      <article>
        <time class="text-xs uppercase tracking-wide text-zinc-500">
          {{ post.created_at | date: "longDate" }}
        </time>
        <h1 class="mt-1 text-3xl font-semibold tracking-tight">{{ post.title }}</h1>
        @if (auth.authed()) {
          <div class="mt-3 flex gap-3 text-sm">
            <a
              [routerLink]="['/edit', post.slug]"
              class="text-violet-600 dark:text-violet-400 hover:underline"
            >
              Edit
            </a>
            <button (click)="remove(post)" class="text-red-500 hover:underline">Delete</button>
          </div>
        }
        <app-markdown class="mt-6 block" [source]="post.body" />
      </article>
    } @else {
      <p class="text-zinc-500 text-sm">Loading…</p>
    }
  `,
})
export class PostDetail implements OnInit {
  readonly slug = input.required<string>();
  protected readonly auth = inject(Auth);
  private readonly api = inject(BlogApi);
  private readonly router = inject(Router);
  protected readonly post = signal<Post | null>(null);
  protected readonly error = signal<string | null>(null);

  ngOnInit(): void {
    this.api
      .get(this.slug())
      .then((post) => this.post.set(post))
      .catch((e: unknown) => this.error.set(errorMessage(e)));
  }

  async remove(post: Post): Promise<void> {
    if (!confirm("Delete this post?")) return;
    try {
      await this.api.delete(post.id);
      await this.router.navigateByUrl("/");
    } catch (e) {
      this.error.set(errorMessage(e));
    }
  }
}
