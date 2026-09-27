import { Routes } from "@angular/router";
import { Editor } from "./pages/editor";
import { Login } from "./pages/login";
import { PostDetail } from "./pages/post-detail";
import { PostList } from "./pages/post-list";

export const routes: Routes = [
  { path: "", component: PostList },
  { path: "posts/:slug", component: PostDetail },
  { path: "login", component: Login },
  { path: "write", component: Editor },
  { path: "edit/:slug", component: Editor },
];
