import { useEffect, useState, type FormEvent } from "react";
import { useNavigate, useParams } from "react-router-dom";
import { createPost, getPost, updatePost } from "../api";

const fieldCls =
  "w-full rounded-lg border border-zinc-300 dark:border-zinc-700 bg-transparent px-3 py-2 text-sm " +
  "focus:outline-none focus:ring-2 focus:ring-violet-500 focus:border-transparent";

export function Editor() {
  const { slug } = useParams<{ slug: string }>();
  const editing = slug !== undefined;
  const [id, setId] = useState<string | null>(null);
  const [title, setTitle] = useState("");
  const [body, setBody] = useState("");
  const [published, setPublished] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [loaded, setLoaded] = useState(!editing);
  const navigate = useNavigate();

  useEffect(() => {
    if (!slug) return;
    getPost(slug)
      .then((post) => {
        setId(post.id);
        setTitle(post.title);
        setBody(post.body);
        setPublished(post.published);
        setLoaded(true);
      })
      .catch((e: Error) => setError(e.message));
  }, [slug]);

  async function handleSubmit(e: FormEvent) {
    e.preventDefault();
    setBusy(true);
    setError(null);
    try {
      let saved;
      if (editing && id) {
        saved = await updatePost(id, { title, body, published });
      } else {
        saved = await createPost({ title, body });
        // Posts are created unpublished; flip the flag in a follow-up update.
        if (published) saved = await updatePost(saved.id, { published: true });
      }
      navigate(saved.published ? `/${saved.slug}` : "/");
    } catch (err) {
      setError((err as Error).message);
      setBusy(false);
    }
  }

  if (!loaded && !error) return <p className="text-zinc-500 text-sm">Loading…</p>;

  return (
    <div>
      <h1 className="text-2xl font-semibold tracking-tight">
        {editing ? "Edit post" : "New post"}
      </h1>
      <form onSubmit={handleSubmit} className="mt-6 space-y-4">
        <input
          type="text"
          required
          placeholder="Title"
          value={title}
          onChange={(e) => setTitle(e.target.value)}
          className={fieldCls}
        />
        <textarea
          required
          placeholder="Write in markdown…"
          value={body}
          onChange={(e) => setBody(e.target.value)}
          rows={16}
          className={`${fieldCls} font-mono resize-y`}
        />
        <div className="flex items-center justify-between">
          <label className="flex items-center gap-2 text-sm text-zinc-600 dark:text-zinc-400 cursor-pointer">
            <input
              type="checkbox"
              checked={published}
              onChange={(e) => setPublished(e.target.checked)}
              className="h-4 w-4 rounded accent-violet-600"
            />
            Published
          </label>
          <button
            type="submit"
            disabled={busy}
            className="rounded-lg bg-violet-600 hover:bg-violet-500 disabled:opacity-50 px-4 py-2 text-sm font-medium text-white transition-colors"
          >
            {busy ? "Saving…" : "Save"}
          </button>
        </div>
        {error && <p className="text-sm text-red-500">{error}</p>}
      </form>
    </div>
  );
}
