const { NxAppWebpackPlugin } = require('@nx/webpack/app-plugin');
const { join } = require('path');
const webpack = require('webpack');

// Optional NestJS packages that are not installed in this project.
// NestJS tries to dynamically require these at runtime — ignore them at
// build time so webpack doesn't fail when they're missing.
const NESTJS_OPTIONAL_DEPS = [
  '@nestjs/microservices',
  '@nestjs/microservices/microservices-module',
  '@nestjs/websockets/socket-module',
  'class-validator',
  'class-transformer',
  'class-transformer/storage',
];

module.exports = {
  output: {
    path: join(__dirname, 'dist'),
    clean: true,
    ...(process.env.NODE_ENV !== 'production' && {
      devtoolModuleFilenameTemplate: '[absolute-resource-path]',
    }),
  },
  plugins: [
    new NxAppWebpackPlugin({
      target: 'node',
      compiler: 'tsc',
      main: './src/main.ts',
      tsConfig: './tsconfig.app.json',
      assets: ['./src/assets'],
      optimization: false,
      outputHashing: 'none',
      generatePackageJson: false,
      sourceMap: true,
      // Bundle all node_modules into main.js — eliminates the need to ship
      // node_modules in the Docker image, reducing image size significantly.
      externalDependencies: 'none',
    }),
    // Ignore optional NestJS deps that aren't installed. NestJS loads these
    // lazily via try/catch require() so missing them at runtime is safe.
    new webpack.IgnorePlugin({
      checkResource(resource) {
        if (!NESTJS_OPTIONAL_DEPS.includes(resource)) return false;
        try {
          require.resolve(resource);
          return false; // installed — bundle it
        } catch {
          return true; // not installed — ignore
        }
      },
    }),
  ],
};
