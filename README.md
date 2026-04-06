# Claude Legacy

> Run [Claude](https://claude.ai) on older iOS versions — no iOS 18 required.

The official Claude app from Anthropic requires **iOS 18**. The claude.ai website works starting from **iOS 16.4**. This project goes further, bringing Claude to **iOS 15** and potentially earlier.

<p align="center">
  <img src="assets/screenshot_1.PNG" width="300" alt="Claude running on iOS 15"/>
</p>

## How It Works

Claude Legacy is a lightweight native iOS app that wraps claude.ai in a `WKWebView` and injects a JavaScript patch at page load. The patch rewrites incompatible ES2022+ syntax (like class static initialization blocks) that older Safari versions can't parse, allowing the site to load and run normally.

## Dependencies
- [legacy-transpiler](https://github.com/mgefimov/legacy-transpiler) - Fast runtime transpiler for unsupported JS syntax
- [Polyfills](https://github.com/PoomSmart/Polyfills) - Polyfills for unsupported JS api

## Installation

1. Download the latest `.ipa` from [Releases](https://github.com/mgefimov/claude-legacy-ios/releases)
2. Install using [TrollStore](https://github.com/opa334/TrollStore) or any other sideloading method (e.g. [AltStore](https://altstore.io), [Sideloadly](https://sideloadly.io))

## Compatibility

| Device | iOS Version | Status |
|--------|-------------|--------|
| iPhone 13 | 15.5 | ✅ Verified |
