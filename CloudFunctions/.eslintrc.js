module.exports = {
  root: true,
  parser: "@typescript-eslint/parser",
  parserOptions: {
    project: ["tsconfig.json"],
    sourceType: "module",
  },
  plugins: ["@typescript-eslint"],
  extends: [
    "eslint:recommended",
    "plugin:@typescript-eslint/recommended",
  ],
  ignorePatterns: ["lib/**", "node_modules/**"],
  rules: {
    "@typescript-eslint/no-unused-vars": "error",
  },
};
