import { HttpErrorResponse } from "@angular/common/http";

export interface PostSummary {
  id: string;
  title: string;
  slug: string;
  excerpt: string;
  published_at: string;
}

export interface Post {
  id: string;
  title: string;
  slug: string;
  body: string;
  published: boolean;
  author_id: string;
  created_at: string;
  updated_at: string;
}

/** Extract the API's `{"error": "..."}` message, falling back sensibly. */
export function errorMessage(e: unknown): string {
  if (e instanceof HttpErrorResponse) {
    const apiError = (e.error as { error?: string } | null)?.error;
    return apiError ?? e.message;
  }
  return e instanceof Error ? e.message : String(e);
}
