import { Component, inject, OnInit, signal } from "@angular/core";
import { FormsModule } from "@angular/forms";
import { ActivatedRoute, Router } from "@angular/router";
import { BlogService } from "../blog.service";
import { errorMessage } from "../models";

@Component({
  selector: "app-editor",
  standalone: true,
  imports: [FormsModule],
  template: `
    @if (!loaded() && !error()) {
      <p class="text-zinc-500 text-sm">Loading…</p>
    } @else {
      <h1 class="text-2xl font-semibold tracking-tight">
        {{ editing ? "Edit post" : "New post" }}
      </h1>
      <form (ngSubmit)="save()" class="mt-6 space-y-4">
        <input
          type="text"
          name="title"
          required
          placeholder="Title"
          [(ngModel)]="title"
          class="w-full rounded-lg border border-zinc-300 dark:border-zinc-700 bg-transparent px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent"
        />
        <textarea
          name="body"
          required
          placeholder="Write in markdown…"
          [(ngModel)]="body"
          rows="16"
          class="w-full rounded-lg border border-zinc-300 dark:border-zinc-700 bg-transparent px-3 py-2 text-sm font-mono resize-y focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent"
        ></textarea>
        <div class="flex items-center justify-between">
          <label
            class="flex items-center gap-2 text-sm text-zinc-600 dark:text-zinc-400 cursor-pointer"
          >
            <input
              type="checkbox"
              name="published"
              [(ngModel)]="published"
              class="h-4 w-4 rounded accent-violet-600"
            />
            Published
          </label>
          <button
            type="submit"
            [disabled]="busy()"
            class="rounded-lg bg-violet-600 hover:bg-violet-500 disabled:opacity-50 px-4 py-2 text-sm font-medium text-white transition-colors"
          >
            {{ busy() ? "Saving…" : "Save" }}
          </button>
        </div>
        @if (error()) {
          <p class="text-sm text-red-500">{{ error() }}</p>
        }
      </form>
    }
  `,
})
export class EditorComponent implements OnInit {
  private blog = inject(BlogService);
  private route = inject(ActivatedRoute);
  private router = inject(Router);

  editing = false;
  private id: string | null = null;
  title = "";
  body = "";
  published = false;

  readonly loaded = signal(false);
  readonly busy = signal(false);
  readonly error = signal<string | null>(null);

  ngOnInit(): void {
    const slug = this.route.snapshot.paramMap.get("slug");
    this.editing = slug !== null;
    if (!slug) {
      this.loaded.set(true);
      return;
    }
    this.blog
      .get(slug)
      .then((post) => {
        this.id = post.id;
        this.title = post.title;
        this.body = post.body;
        this.published = post.published;
        this.loaded.set(true);
      })
      .catch((e: unknown) => this.error.set(errorMessage(e)));
  }

  async save(): Promise<void> {
    this.busy.set(true);
    this.error.set(null);
    try {
      let saved;
      if (this.editing && this.id) {
        saved = await this.blog.update(this.id, {
          title: this.title,
          body: this.body,
          published: this.published,
        });
      } else {
        saved = await this.blog.create({ title: this.title, body: this.body });
        // Posts are created unpublished; flip the flag in a follow-up update.
        if (this.published) saved = await this.blog.update(saved.id, { published: true });
      }
      await this.router.navigateByUrl(saved.published ? `/${saved.slug}` : "/");
    } catch (e) {
      this.error.set(errorMessage(e));
      this.busy.set(false);
    }
  }
}
