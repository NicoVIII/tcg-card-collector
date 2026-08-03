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
];
