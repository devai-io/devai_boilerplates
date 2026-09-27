import { Component, inject, OnInit, signal } from "@angular/core";
import { DatePipe } from "@angular/common";
import { RouterLink } from "@angular/router";
import { BlogApi } from "../blog-api";
import { errorMessage, PostSummary } from "../models";

@Component({
  selector: "app-post-list",
  imports: [RouterLink, DatePipe],
  template: `
    @if (error()) {
      <p class="text-red-500 text-sm">{{ error() }}</p>
    } @else if (posts(); as posts) {
      @for (post of posts; track post.id) {
        <article class="mb-10">
          <time class="text-xs uppercase tracking-wide text-zinc-500">
            {{ post.published_at | date: "mediumDate" }}
          </time>
          <h2 class="mt-1 text-xl font-semibold tracking-tight">
            <a
              [routerLink]="['/posts', post.slug]"
              class="hover:text-violet-600 dark:hover:text-violet-400"
            >
              {{ post.title }}
            </a>
          </h2>
          <p class="mt-2 text-sm text-zinc-600 dark:text-zinc-400 leading-relaxed">
            {{ post.excerpt }}
          </p>
        </article>
      } @empty {
        <p class="text-zinc-500 text-sm">No posts yet.</p>
      }
    } @else {
      <p class="text-zinc-500 text-sm">Loading…</p>
    }
  `,
})
export class PostList implements OnInit {
  private readonly api = inject(BlogApi);
  protected readonly posts = signal<PostSummary[] | null>(null);
  protected readonly error = signal<string | null>(null);

  ngOnInit(): void {
    this.api
      .list()
      .then((posts) => this.posts.set(posts))
      .catch((e: unknown) => this.error.set(errorMessage(e)));
  }
}
