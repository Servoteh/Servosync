import { defineConfig } from 'vitest/config';

export default defineConfig({
  test: {
    environment: 'node',
    include: ['tests/**/*.test.js', 'src/**/*.test.js'],
    globals: false,
    /* Ne pokretati Node worker testove u Vitest-u (koriste node:test). */
    exclude: ['workers/**', 'node_modules/**', 'dist/**'],
    reporters: ['default'],
  },
});
