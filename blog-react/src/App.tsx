import { useState } from "react";
import { Link, Route, Routes, useNavigate } from "react-router-dom";
import { isAuthed, logout } from "./api";
import { PostList } from "./pages/PostList";
import { PostDetail } from "./pages/PostDetail";
import { Login } from "./pages/Login";
import { Editor } from "./pages/Editor";

export default function App() {
  const [authed, setAuthed] = useState(isAuthed());
  const navigate = useNavigate();

  function handleLogout() {
    logout();
    setAuthed(false);
    navigate("/");
  }

  return (
    <div className="min-h-screen bg-white dark:bg-zinc-950 text-zinc-900 dark:text-zinc-100 antialiased">
      <header className="border-b border-zinc-200 dark:border-zinc-800">
        <div className="mx-auto max-w-2xl px-6 py-5 flex items-center justify-between">
          <Link to="/" className="font-semibold tracking-tight">
            blog
          </Link>
          <nav className="flex items-center gap-4 text-sm text-zinc-500 dark:text-zinc-400">
            {authed ? (
              <>
                <Link to="/write" className="hover:text-zinc-900 dark:hover:text-zinc-100">
                  Write
                </Link>
                <button
                  onClick={handleLogout}
                  className="hover:text-zinc-900 dark:hover:text-zinc-100"
                >
                  Log out
                </button>
              </>
            ) : (
              <Link to="/login" className="hover:text-zinc-900 dark:hover:text-zinc-100">
                Log in
              </Link>
            )}
          </nav>
        </div>
      </header>
      <main className="mx-auto max-w-2xl px-6 py-10">
        <Routes>
          <Route path="/" element={<PostList />} />
          <Route path="/login" element={<Login onLogin={() => setAuthed(true)} />} />
          <Route path="/write" element={<Editor />} />
          <Route path="/edit/:slug" element={<Editor />} />
          <Route path="/:slug" element={<PostDetail authed={authed} />} />
        </Routes>
      </main>
    </div>
  );
}
