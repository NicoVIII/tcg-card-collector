import { CatalogPage } from "./catalog_page";
import { ImportPage } from "./import_page";
import { InventoryPage } from "./inventory_page";
import { SettingsPage } from "./settings_page";

export const pageRegistry = {
  "/import": ImportPage,
  "/catalog": CatalogPage,
  "/inventory": InventoryPage,
  "/settings": SettingsPage,
} as const;
