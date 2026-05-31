module.exports = {
  root: true,
  env: {
    browser: true,
    es2022: true,
    node: true,
  },
  parser: "@typescript-eslint/parser",
  parserOptions: {
    ecmaVersion: "latest",
    sourceType: "module",
  },
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
    "plugin:solid/typescript",
    "prettier",
  ],
  plugins: ["@typescript-eslint", "solid"],
  settings: {
    solid: {
      version: "detect",
    },
  },
  ignorePatterns: ["dist", "node_modules"],
};
