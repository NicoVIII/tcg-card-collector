import { For, Show, type ParentProps } from "solid-js";
import { A } from "@solidjs/router";
import { PlacementWorkBadge } from "./components/placement_work_badge";
import { useAppVersionQuery } from "./data/system/query";
import { navRoutes } from "./routes";

export default function App(props: ParentProps) {
  const versionQuery = useAppVersionQuery();

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
                  <PlacementWorkBadge />
                </Show>
              </A>
            )}
          </For>
        </nav>
      </header>
      <section class="page-panel">{props.children}</section>
      <footer class="app-footer">
        {/* Absent while loading or on error: a version string is not worth an
            error banner on every screen. */}
        <Show when={versionQuery.data}>{(version) => <span>v{version()}</span>}</Show>
      </footer>
    </main>
  );
}
