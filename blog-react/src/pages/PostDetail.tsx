import { useEffect, useState } from "react";
import { Link, useNavigate, useParams } from "react-router-dom";
import { deletePost, getPost, type Post } from "../api";
import { Markdown } from "../markdown";

export function PostDetail({ authed }: { authed: boolean }) {
  const { slug } = useParams<{ slug: string }>();
  const [post, setPost] = useState<Post | null>(null);
  const [error, setError] = useState<string | null>(null);
  const navigate = useNavigate();

  useEffect(() => {
    if (!slug) return;
    getPost(slug)
      .then(setPost)
      .catch((e: Error) => setError(e.message));
  }, [slug]);

  async function handleDelete() {
    if (!post || !confirm("Delete this post?")) return;
    try {
      await deletePost(post.id);
      navigate("/");
    } catch (e) {
      setError((e as Error).message);
    }
  }

  if (error) return <p className="text-red-500 text-sm">{error}</p>;
  if (!post) return <p className="text-zinc-500 text-sm">Loading…</p>;

  return (
    <article>
      <time className="text-xs uppercase tracking-wide text-zinc-500">
        {new Date(post.created_at).toLocaleDateString(undefined, {
          year: "numeric",
          month: "long",
          day: "numeric",
        })}
      </time>
      <h1 className="mt-1 text-3xl font-semibold tracking-tight">{post.title}</h1>
      {authed && (
        <div className="mt-3 flex gap-3 text-sm">
          <Link
            to={`/edit/${post.slug}`}
            className="text-violet-600 dark:text-violet-400 hover:underline"
          >
            Edit
          </Link>
          <button onClick={handleDelete} className="text-red-500 hover:underline">
            Delete
          </button>
        </div>
      )}
      <div className="mt-6">
        <Markdown source={post.body} />
      </div>
    </article>
  );
}
