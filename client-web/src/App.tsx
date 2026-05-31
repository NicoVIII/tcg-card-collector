import { For, createSignal } from "solid-js";
import { Dynamic } from "solid-js/web";
import { CatalogPage } from "./pages/catalog_page";
import { ImportPage } from "./pages/import_page";
import { InventoryPage } from "./pages/inventory_page";
import { SettingsPage } from "./pages/settings_page";
import { routes } from "./routes";

const pages = {
  "/import": ImportPage,
  "/catalog": CatalogPage,
  "/inventory": InventoryPage,
  "/settings": SettingsPage,
} as const;

export default function App() {
  const [path, setPath] = createSignal("/import");
  const current = () => routes.find((route) => route.path === path()) ?? routes[0];
  const currentPage = () => pages[current().path];

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
