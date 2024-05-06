module.exports = {
  parserOptions: {
    extraFileExtensions: [".svelte"],
  },
  extends: [
    "prettier",
    "eslint:recommended",
    "plugin:svelte/recommended",
  ],
  overrides: [
    {
      files: ["*.svelte"],
      parser: "svelte-eslint-parser",
      parserOptions: {
        parser: "@typescript-eslint/parser",
      },
    },
  ],
  rules: {
    "svelte/no-unused-svelte-ignore": "off",
  },
};
