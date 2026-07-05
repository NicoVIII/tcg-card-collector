import { For, Show, type ParentProps } from "solid-js";
import { A } from "@solidjs/router";
import { UnplacedBadge } from "./components/unplaced_badge";
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
                <Show when={route.path === "/placement"}>
                  <UnplacedBadge />
                </Show>
              </A>
            )}
          </For>
        </nav>
      </header>
      <section class="page-panel">{props.children}</section>
    </main>
  );
}
