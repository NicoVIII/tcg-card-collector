import { CatalogPage } from "./catalog_page";
import { CollectionPage } from "./collection_page";
import { InventoryPage } from "./inventory_page";
import { SettingsPage } from "./settings_page";

export const pageRegistry = {
  "/collection": CollectionPage,
  "/catalog": CatalogPage,
  "/inventory": InventoryPage,
  "/settings": SettingsPage,
} as const;
