export type AppRoute = {
  path: "/import" | "/catalog" | "/inventory" | "/settings";
  label: string;
  description: string;
};

export const routes: AppRoute[] = [
  { path: "/import", label: "Import", description: "Collection import flow will live here." },
  { path: "/catalog", label: "Catalog", description: "Catalog browse and search will live here." },
  {
    path: "/inventory",
    label: "Inventory",
    description: "Inventory planning and grouping will live here.",
  },
  {
    path: "/settings",
    label: "Settings",
    description: "Runtime settings and manual refresh will live here.",
  },
];
