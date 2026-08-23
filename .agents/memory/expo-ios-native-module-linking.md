---
name: Expo iOS native module linking
description: How to confirm a local Expo module is actually linked into an iOS development build.
---

For a local Expo module on Apple platforms, a module appearing in the autolinking
**search** result does not prove that CocoaPods will include its native Swift source.
It needs an iOS podspec and must appear in the Apple **resolve** output with the
expected Pod and module class.

**Why:** The Bookshelf AR bridge was discoverable through its Expo module config but
was excluded from Apple resolution until its podspec declared the Expo core dependency
and required system frameworks.

**How to apply:** After adding or changing a local iOS Expo module, run
`pnpm exec expo-modules-autolinking resolve --platform apple --json` from the app
directory. Confirm the module lists a Pod, its Swift module name, and the registered
Expo module class before relying on a development build for validation.