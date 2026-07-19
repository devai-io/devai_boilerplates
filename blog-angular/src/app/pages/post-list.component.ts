import { Component, inject, OnInit, signal } from "@angular/core";
import { DatePipe } from "@angular/common";
import { RouterLink } from "@angular/router";
import { BlogService } from "../blog.service";
import { errorMessage, PostSummary } from "../models";

@Component({
  selector: "app-post-list",
  standalone: true,
  imports: [RouterLink, DatePipe],
  template: `
    @if (error()) {
      <p class="text-red-500 text-sm">{{ error() }}</p>
    } @else if (!posts()) {
      <p class="text-zinc-500 text-sm">Loading…</p>
    } @else if (posts()!.length === 0) {
      <p class="text-zinc-500 text-sm">No posts yet.</p>
    } @else {
      <ul class="space-y-10">
        @for (post of posts(); track post.id) {
          <li>
            <article>
              <time class="text-xs uppercase tracking-wide text-zinc-500">
                {{ post.published_at | date: "mediumDate" }}
              </time>
              <h2 class="mt-1 text-xl font-semibold tracking-tight">
                <a
                  [routerLink]="['/', post.slug]"
                  class="hover:text-violet-600 dark:hover:text-violet-400"
                >
                  {{ post.title }}
                </a>
              </h2>
              <p class="mt-2 text-sm text-zinc-600 dark:text-zinc-400 leading-relaxed">
                {{ post.excerpt }}
              </p>
            </article>
          </li>
        }
      </ul>
    }
  `,
})
export class PostListComponent implements OnInit {
  private blog = inject(BlogService);
  readonly posts = signal<PostSummary[] | null>(null);
  readonly error = signal<string | null>(null);

  ngOnInit(): void {
    this.blog
      .list()
      .then((posts) => this.posts.set(posts))
      .catch((e: unknown) => this.error.set(errorMessage(e)));
  }
}
