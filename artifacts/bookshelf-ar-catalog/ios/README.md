# Bookshelf AR Catalog — native iOS client

This directory is the standalone SwiftUI replacement for the former Expo client.
It has no React Native, Expo, CocoaPods, or third-party runtime dependency.

## Open and run

Open `BookshelfARCatalog.xcodeproj` in Xcode 15 or later on macOS, select the
`BookshelfARCatalog` scheme, configure a signing team, and run on a physical
iPhone 12 or newer. ARKit world mapping is not available in the simulator.

The app target is iPhone-only, portrait-only, and declares camera and
When-In-Use location permission explanations in `BookshelfARCatalog/Info.plist`.

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
