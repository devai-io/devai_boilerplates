import { inject, Injectable } from "@angular/core";
import { HttpClient } from "@angular/common/http";
import { firstValueFrom } from "rxjs";
import { Post, PostSummary } from "./models";

@Injectable({ providedIn: "root" })
export class BlogService {
  private http = inject(HttpClient);
  private base = NG_APP_API_URL;

  list(): Promise<PostSummary[]> {
    return firstValueFrom(this.http.get<PostSummary[]>(`${this.base}/posts`));
  }

  get(slug: string): Promise<Post> {
    return firstValueFrom(this.http.get<Post>(`${this.base}/posts/${encodeURIComponent(slug)}`));
  }

  create(input: { title: string; body: string }): Promise<Post> {
    return firstValueFrom(this.http.post<Post>(`${this.base}/posts`, input));
  }

  update(id: string, input: { title?: string; body?: string; published?: boolean }): Promise<Post> {
    return firstValueFrom(
      this.http.put<Post>(`${this.base}/posts/${encodeURIComponent(id)}`, input),
    );
  }

  delete(id: string): Promise<void> {
    return firstValueFrom(
      this.http.delete<void>(`${this.base}/posts/${encodeURIComponent(id)}`),
    );
  }
}
