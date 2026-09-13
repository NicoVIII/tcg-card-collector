import js from "@eslint/js";
import tseslint from "@typescript-eslint/eslint-plugin";
import solid from "eslint-plugin-solid/configs/typescript";

export default [
  { ignores: ["dist/**", "node_modules/**", "src/data/skirout/**"] },
  js.configs.recommended,
  ...tseslint.configs["flat/recommended"],
  solid,
  {
    settings: { solid: { version: "detect" } },
  },
  {
    // Code-shape floor, mirroring the backend's glinter gate (server/gleam.toml).
    // Escape hatch: `// eslint-disable-next-line <rule> -- <reason>`.
    rules: {
      // Top-down order (AGENTS.md "Code Shape"); the base rule misreads TS types.
      "no-use-before-define": "off",
      "@typescript-eslint/no-use-before-define": [
        "error",
        { functions: true, classes: true, variables: true, typedefs: true },
      ],
      // Same thresholds as glinter's function_complexity (10) and deep_nesting (5
      // levels counting the function body, which max-depth does not count).
      complexity: ["error", 10],
      "max-depth": ["error", 4],
    },
  },
];
