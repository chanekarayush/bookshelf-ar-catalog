# Bookshelf AR Catalog — native iOS client

This directory is the standalone SwiftUI replacement for the former Expo client.
It has no React Native, Expo, CocoaPods, or third-party runtime dependency.

## Open, sign, and run

Open `BookshelfARCatalog.xcodeproj` in Xcode 15 or later on macOS. The shared
`BookshelfARCatalog` scheme is checked in under the project and includes Build,
Run, Test, Profile, Analyze, and Archive actions.

On first open, select the app target and choose your Apple development team in
Signing & Capabilities. **Automatically manage signing** is enabled, and no
developer team, certificate, provisioning profile, or signing secret is
committed. The default bundle identifier is `com.bookshelf.ar.catalog`; change
it in the target's Signing or Build Settings if your team cannot register that
identifier. This is the only per-developer setup required.

Run on a physical iPhone 12 or newer with ARKit world tracking. The target is
iPhone-only, portrait-only, and iOS 17.0 or later. ARKit world mapping is not
available in the simulator; the simulator is useful only for inspecting
non-AR SwiftUI screens. The target filters devices with the `arkit` required
capability and does not request background location, iCloud, push notifications,
or any other unused entitlement.

The checked-in asset catalog supplies `AppIcon`, `AccentColor`, and the
`LaunchBackground` color referenced by `BookshelfARCatalog/Info.plist`.
Camera and When-In-Use location explanations are also declared there. Open
Library is accessed over HTTPS and does not require an App Transport Security
exception.

## Local data compatibility

The Swift store uses the same `bookshelf-ar-catalog:v1` JSON field names as the
previous local client and includes a one-time reader for its local AsyncStorage
directory. Apple only permits this migration when the native target is signed
with the same app identifier/sandbox as the installed legacy build; a new app
identifier cannot access another app's on-device container. ARWorldMap files
remain in Application Support under
`BookshelfAR/shelf-<shelf-id>.arexperience`.

## Physical-device acceptance pass

1. Add an ISBN by camera scan or manual entry, edit its metadata, and save it.
2. Assign it to an existing or new bookcase, then map the full shelf level.
3. Place the book, force-quit, relaunch, and confirm the marker returns.
4. Try locating from another area and confirm coarse GPS guidance can be
   skipped without blocking AR.
5. Re-scan a shelf and confirm its old placements are cleared.

Also verify on the signed device:

- Camera permission appears when scanning; denying it leaves the manual ISBN
  path usable.
- When-In-Use location permission is requested only while saving a shelf map;
  locating can continue with GPS unavailable when permission is skipped or
  denied.
- Offline or unknown ISBN lookup falls back to editable manual metadata.
- A saved shelf relocalizes after relaunch, and a failed relocalization offers
  a re-scan instead of claiming the shelf was found.

## Validation limits

Xcode, `xcodebuild`, ARKit, and a physical iPhone require macOS hardware and
are not available in the Linux workspace. On macOS, select the shared scheme
and run **Product → Build**, **Product → Analyze**, and **Product → Archive**
before the device acceptance pass above. Confirm the archive has no signing or
missing-asset warnings, then install the Debug build on a supported iPhone.

For a simulator-only packaging check on macOS, use:

```sh
xcodebuild -project BookshelfARCatalog.xcodeproj \
  -scheme BookshelfARCatalog \
  -configuration Debug \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO build
```

For a signed release archive, choose a team in Xcode first, then run the
`Archive` action from the shared scheme or use Xcode's normal
`-destination 'generic/platform=iOS' archive` workflow.
