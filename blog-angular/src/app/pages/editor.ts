import { Component, inject, input, OnInit, signal } from "@angular/core";
import { FormsModule } from "@angular/forms";
import { Router } from "@angular/router";
import { BlogApi } from "../blog-api";
import { errorMessage } from "../models";

const fieldCls =
  "w-full rounded-lg border border-zinc-300 dark:border-zinc-700 bg-transparent px-3 py-2 text-sm " +
  "focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent";

@Component({
  selector: "app-editor",
  imports: [FormsModule],
  template: `
    @if (!loaded()) {
      @if (error()) {
        <p class="text-red-500 text-sm">{{ error() }}</p>
      } @else {
        <p class="text-zinc-500 text-sm">Loading…</p>
      }
    } @else {
      <h1 class="text-2xl font-semibold tracking-tight">{{ id() ? "Edit post" : "New post" }}</h1>
      <form (ngSubmit)="save()" class="mt-6 space-y-4">
        <input
          type="text"
          name="title"
          required
          placeholder="Title"
          [(ngModel)]="title"
          [class]="fieldCls"
        />
        <textarea
          name="body"
          required
          rows="16"
          placeholder="Write in markdown…"
          [(ngModel)]="body"
          [class]="fieldCls + ' font-mono resize-y'"
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
        @if (notice()) {
          <p class="text-sm text-zinc-500">{{ notice() }}</p>
        }
        @if (error()) {
          <p class="text-sm text-red-500">{{ error() }}</p>
        }
      </form>
    }
  `,
})
export class Editor implements OnInit {
  readonly slug = input<string>();
  private readonly api = inject(BlogApi);
  private readonly router = inject(Router);
  protected readonly fieldCls = fieldCls;

  protected readonly id = signal<string | null>(null);
  protected readonly title = signal("");
  protected readonly body = signal("");
  protected readonly published = signal(false);
  protected readonly loaded = signal(false);
  protected readonly busy = signal(false);
  protected readonly notice = signal<string | null>(null);
  protected readonly error = signal<string | null>(null);

  ngOnInit(): void {
    const slug = this.slug();
    if (!slug) {
      this.loaded.set(true);
      return;
    }
    this.api
      .get(slug)
      .then((post) => {
        this.id.set(post.id);
        this.title.set(post.title);
        this.body.set(post.body);
        this.published.set(post.published);
        this.loaded.set(true);
      })
      .catch((e: unknown) => this.error.set(errorMessage(e)));
  }

  async save(): Promise<void> {
    this.busy.set(true);
    this.error.set(null);
    this.notice.set(null);
    const id = this.id();
    const fields = { title: this.title(), body: this.body() };
    try {
      let saved = id
        ? await this.api.update(id, { ...fields, published: this.published() })
        : await this.api.create(fields);
      // Posts are created unpublished; flip the flag in a follow-up update.
      if (!id && this.published()) saved = await this.api.update(saved.id, { published: true });
      if (saved.published) {
        await this.router.navigate(["/posts", saved.slug]);
        return;
      }
      // The API never serves drafts back, so keep editing this one right here.
      this.id.set(saved.id);
      this.notice.set("Draft saved. Tick Published and save again to make it public.");
    } catch (e) {
      this.error.set(errorMessage(e));
    }
    this.busy.set(false);
  }
}
