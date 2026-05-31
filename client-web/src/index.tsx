import { render } from "solid-js/web";
import { QueryClientProvider } from "@tanstack/solid-query";
import App from "./App";
import { queryClient } from "./data/tanstack_helper";
import "./styles.css";

const root = document.getElementById("root");

if (!root) {
  throw new Error("Root element not found");
}

render(
  () => (
    <QueryClientProvider client={queryClient}>
      <App />
    </QueryClientProvider>
  ),
  root,
);
