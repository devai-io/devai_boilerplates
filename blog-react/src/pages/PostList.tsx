import { useEffect, useState } from "react";
import { Link } from "react-router-dom";
import { listPosts, type PostSummary } from "../api";

export function PostList() {
  const [posts, setPosts] = useState<PostSummary[] | null>(null);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    listPosts()
      .then(setPosts)
      .catch((e: Error) => setError(e.message));
  }, []);

  if (error) return <p className="text-red-500 text-sm">{error}</p>;
  if (!posts) return <p className="text-zinc-500 text-sm">Loading…</p>;
  if (posts.length === 0)
    return <p className="text-zinc-500 text-sm">No posts yet.</p>;

  return (
    <ul className="space-y-10">
      {posts.map((post) => (
        <li key={post.id}>
          <article>
            <time className="text-xs uppercase tracking-wide text-zinc-500">
              {new Date(post.published_at).toLocaleDateString(undefined, {
                year: "numeric",
                month: "short",
                day: "numeric",
              })}
            </time>
            <h2 className="mt-1 text-xl font-semibold tracking-tight">
              <Link
                to={`/${post.slug}`}
                className="hover:text-violet-600 dark:hover:text-violet-400"
              >
                {post.title}
              </Link>
            </h2>
            <p className="mt-2 text-sm text-zinc-600 dark:text-zinc-400 leading-relaxed">
              {post.excerpt}
            </p>
          </article>
        </li>
      ))}
    </ul>
  );
}
