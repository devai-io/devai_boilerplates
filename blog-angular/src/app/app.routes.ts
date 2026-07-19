import { Routes } from "@angular/router";
import { PostListComponent } from "./pages/post-list.component";
import { PostDetailComponent } from "./pages/post-detail.component";
import { LoginComponent } from "./pages/login.component";
import { EditorComponent } from "./pages/editor.component";

export const routes: Routes = [
  { path: "", component: PostListComponent },
  { path: "login", component: LoginComponent },
  { path: "write", component: EditorComponent },
  { path: "edit/:slug", component: EditorComponent },
  { path: ":slug", component: PostDetailComponent },
];
