// Default /api: same origin, forwarded to the API by nginx (Docker) or Vite (npm run dev).
const BASE = import.meta.env.VITE_API_URL || "/api";
const TOKEN_KEY = "blog_token";

// Token lives in memory; localStorage only rehydrates it across reloads.
let token: string | null = localStorage.getItem(TOKEN_KEY);

export function isAuthed(): boolean {
  return token !== null;
}

export function logout(): void {
  token = null;
  localStorage.removeItem(TOKEN_KEY);
}

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

export class ApiError extends Error {
  status: number;

  constructor(status: number, message: string) {
    super(message);
    this.status = status;
  }
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  const headers: Record<string, string> = { ...(init.headers as Record<string, string>) };
  if (init.body) headers["Content-Type"] = "application/json";
  if (token) headers["Authorization"] = `Bearer ${token}`;

  const res = await fetch(`${BASE}${path}`, { ...init, headers });
  if (!res.ok) {
    let message = res.statusText;
    try {
      const data = (await res.json()) as { error?: string };
      if (data.error) message = data.error;
    } catch {
      // non-JSON error body; keep statusText
    }
    throw new ApiError(res.status, message);
  }
  if (res.status === 204) return undefined as T;
  return (await res.json()) as T;
}

export async function login(email: string, password: string): Promise<void> {
  const { token: t } = await request<{ token: string }>("/auth/login", {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });
  token = t;
  localStorage.setItem(TOKEN_KEY, t);
}

export function register(email: string, password: string): Promise<{ id: string; email: string }> {
  return request("/auth/register", {
    method: "POST",
    body: JSON.stringify({ email, password }),
  });
}

export function listPosts(): Promise<PostSummary[]> {
  return request("/posts");
}

export function getPost(slug: string): Promise<Post> {
  return request(`/posts/${encodeURIComponent(slug)}`);
}

export function createPost(input: { title: string; body: string }): Promise<Post> {
  return request("/posts", { method: "POST", body: JSON.stringify(input) });
}

export function updatePost(
  id: string,
  input: { title?: string; body?: string; published?: boolean },
): Promise<Post> {
  return request(`/posts/${encodeURIComponent(id)}`, {
    method: "PUT",
    body: JSON.stringify(input),
  });
}

export function deletePost(id: string): Promise<void> {
  return request(`/posts/${encodeURIComponent(id)}`, { method: "DELETE" });
}
