import { For, type ParentProps } from "solid-js";
import { A } from "@solidjs/router";
import { navRoutes } from "./routes";

export default function App(props: ParentProps) {
  return (
    <main class="app-shell">
      <header class="app-header">
        <h1>tcg-card-collector</h1>
        <nav>
          <For each={navRoutes}>
            {(route) => (
              <A class="nav-btn" href={route.path}>
                {route.label}
              </A>
            )}
          </For>
        </nav>
      </header>
      <section class="page-panel">{props.children}</section>
    </main>
  );
}
