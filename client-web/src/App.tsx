import { For, createSignal } from "solid-js";
import { routes } from "./routes";

export default function App() {
  const [path, setPath] = createSignal("/import");
  const current = () => routes.find((route) => route.path === path()) ?? routes[0];

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
        <h2>{current().label}</h2>
        <p>{current().description}</p>
      </section>
    </main>
  );
}
