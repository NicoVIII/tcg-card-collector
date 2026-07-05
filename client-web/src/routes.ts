import type { Component } from "solid-js";
import { CatalogPage } from "./pages/catalog_page";
import { CollectionImportPage } from "./pages/collection_import_page";
import { CollectionPage } from "./pages/collection_page";
import { InsightsPage } from "./pages/insights_page";
import { InventoryPage } from "./pages/inventory_page";
import { PlacementPage } from "./pages/placement_page";
import { SettingsPage } from "./pages/settings_page";

export type AppRoute = {
  path:
    | "/collection"
    | "/collection/import"
    | "/catalog"
    | "/inventory"
    | "/placement"
    | "/settings"
    | "/insights";
  label: string;
  component: Component;
};

// Routes shown as tabs in the main nav — daily-use pages only.
export const navRoutes: AppRoute[] = [
  { path: "/collection", label: "Collection", component: CollectionPage },
  { path: "/catalog", label: "Catalog", component: CatalogPage },
  { path: "/inventory", label: "Inventory", component: InventoryPage },
  { path: "/placement", label: "Place cards", component: PlacementPage },
  { path: "/insights", label: "Insights", component: InsightsPage },
  { path: "/settings", label: "Settings", component: SettingsPage },
];

// All routable pages; setup pages like the import live here but stay out of
// the nav and are reached via in-page links instead.
export const routes: AppRoute[] = [
  ...navRoutes,
  { path: "/collection/import", label: "Import collection", component: CollectionImportPage },
];
