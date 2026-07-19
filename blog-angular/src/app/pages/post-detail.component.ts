import { Component, inject, OnInit, signal } from "@angular/core";
import { DatePipe } from "@angular/common";
import { ActivatedRoute, Router, RouterLink } from "@angular/router";
import { AuthService } from "../auth.service";
import { BlogService } from "../blog.service";
import { MarkdownPipe } from "../markdown";
import { errorMessage, Post } from "../models";

@Component({
  selector: "app-post-detail",
  standalone: true,
  imports: [RouterLink, DatePipe, MarkdownPipe],
  template: `
    @if (error()) {
      <p class="text-red-500 text-sm">{{ error() }}</p>
    } @else if (!post()) {
      <p class="text-zinc-500 text-sm">Loading…</p>
    } @else {
      <article>
        <time class="text-xs uppercase tracking-wide text-zinc-500">
          {{ post()!.created_at | date: "longDate" }}
        </time>
        <h1 class="mt-1 text-3xl font-semibold tracking-tight">{{ post()!.title }}</h1>
        @if (auth.authed()) {
          <div class="mt-3 flex gap-3 text-sm">
            <a
              [routerLink]="['/edit', post()!.slug]"
              class="text-violet-600 dark:text-violet-400 hover:underline"
            >
              Edit
            </a>
            <button (click)="remove()" class="text-red-500 hover:underline">Delete</button>
          </div>
        }
        <div class="mt-6 prose-blog" [innerHTML]="post()!.body | markdown"></div>
      </article>
    }
  `,
})
export class PostDetailComponent implements OnInit {
  readonly auth = inject(AuthService);
  private blog = inject(BlogService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);

  readonly post = signal<Post | null>(null);
  readonly error = signal<string | null>(null);

  ngOnInit(): void {
    const slug = this.route.snapshot.paramMap.get("slug")!;
    this.blog
      .get(slug)
      .then((post) => this.post.set(post))
      .catch((e: unknown) => this.error.set(errorMessage(e)));
  }

  async remove(): Promise<void> {
    const post = this.post();
    if (!post || !confirm("Delete this post?")) return;
    try {
      await this.blog.delete(post.id);
      await this.router.navigateByUrl("/");
    } catch (e) {
      this.error.set(errorMessage(e));
    }
  }
}
