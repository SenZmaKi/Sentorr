// @ts-check
import { defineConfig } from 'astro/config';

// GitHub Pages serves the site beside the signed update feeds at
// https://senzmaki.github.io/Sentorr/, so every internal URL carries the base.
// Pages adds trailing slashes to directory URLs itself, so accept both forms.
export default defineConfig({
  site: 'https://senzmaki.github.io',
  base: '/Sentorr',
  trailingSlash: 'ignore',
});
