import type { Component } from "solid-js";
import { CatalogPage } from "./pages/catalog_page";
import { CollectionPage } from "./pages/collection_page";
import { InventoryPage } from "./pages/inventory_page";
import { SettingsPage } from "./pages/settings_page";

export type AppRoute = {
  path: "/collection" | "/catalog" | "/inventory" | "/settings";
  label: string;
  component: Component;
};

export const routes: AppRoute[] = [
  { path: "/collection", label: "Collection", component: CollectionPage },
  { path: "/catalog", label: "Catalog", component: CatalogPage },
  { path: "/inventory", label: "Inventory", component: InventoryPage },
  { path: "/settings", label: "Settings", component: SettingsPage },
];
