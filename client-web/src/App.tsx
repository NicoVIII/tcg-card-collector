import { For, createSignal } from "solid-js";
import { Dynamic } from "solid-js/web";
import { pageRegistry } from "./pages/registry";
import { routes } from "./routes";

export default function App() {
  const [path, setPath] = createSignal("/import");
  const current = () => routes.find((route) => route.path === path()) ?? routes[0];
  const currentPage = () => pageRegistry[current().path];

  return (
    <main class="app-shell">
      <header class="app-header">
        <h1>tcg-card-collector</h1>
        <nav>
          <For each={routes}>
            {(route) => (
              <button class="nav-btn" onClick={() => setPath(route.path)}>
                {route.label}
              </button>
            )}
          </For>
        </nav>
      </header>
      <section class="page-panel">
        <Dynamic component={currentPage()} />
      </section>
    </main>
  );
}
