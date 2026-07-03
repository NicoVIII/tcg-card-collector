import { For } from "solid-js";
import { render } from "solid-js/web";
import { QueryClientProvider } from "@tanstack/solid-query";
import { Navigate, Route, Router } from "@solidjs/router";
import App from "./App";
import { queryClient } from "./data/tanstack_helper";
import { routes } from "./routes";
import "./styles.css";

const root = document.getElementById("root");

if (!root) {
  throw new Error("Root element not found");
}

render(
  () => (
    <QueryClientProvider client={queryClient}>
      <Router root={App}>
        <For each={routes}>
          {(route) => <Route path={route.path} component={route.component} />}
        </For>
        <Route path="*" component={() => <Navigate href="/collection" />} />
      </Router>
    </QueryClientProvider>
  ),
  root,
);
