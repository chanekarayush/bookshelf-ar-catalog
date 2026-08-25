# Bookshelf AR Catalog

A local-first mobile library app for scanning ISBNs, editing book metadata, mapping
one bookcase level, and locating books later with an ARKit marker.

## MVP scope

- iOS first, validated on iPhone 12 or newer
- One local user, one device, one bookcase level
- One catalog item per normalized ISBN
- Open Library lookup with editable metadata and manual fallback
- Local persistence with AsyncStorage for the first mobile slice
- Android intentionally deferred until local AR persistence and relocalization are proven

## Prerequisites

- Node.js 20 or newer and pnpm 9 or newer
- A fresh checkout of this repository; install from the repository root so the
  workspace links the shared API client package
- Expo Go for the non-AR preview, or macOS with Xcode and CocoaPods for the iOS
  development build
- A physical iPhone 12 or newer for camera-based ARKit mapping and relocalization

## Run locally

Install from the repository root:

```bash
pnpm install
pnpm run app:dev
```

The `dev` command starts the Expo development server on `localhost:8081` by default.
Set `EXPO_HOST=lan` when using Expo Go on a phone connected to the same network:

```bash
EXPO_HOST=lan pnpm run app:dev
```

On Replit, the existing Expo workflow supplies the preview host variables
automatically. Scan its QR code from the URL bar to open the catalog in Expo Go, or
use the Expo web preview for the catalog, metadata, search, and other non-AR flows.
Camera scanning requires granting camera permission. The app requests location
permission when recording the room or area for a mapped shelf; location is optional
for the local catalog but improves shelf selection.

Expo Go and web do not include the checked-in `bookshelf-ar-native` module. On those
previews, the AR shelf flow intentionally displays a native-build message rather than
claiming that the preview is spatially accurate.

## iOS AR development build

The AR shelf flow requires the custom iOS build and is not available in Expo Go. The
valid checked-in project is `artifacts/bookshelf-ar-catalog/ios/BookshelfARCatalog.xcodeproj`.
On macOS, install Xcode (including its command-line tools), CocoaPods, and the iOS
development certificates needed for the connected device. Install JavaScript
dependencies first, then install Pods:

```bash
pnpm install
cd artifacts/bookshelf-ar-catalog
pod install --project-directory=ios
open ios/BookshelfARCatalog.xcworkspace
```

The local module at `modules/bookshelf-ar-native` is linked through the workspace
package and its `expo-module.config.json`/podspec metadata. If `app.json` or native
module metadata changes, regenerate the checked-in project with:

```bash
pnpm run app:prebuild:ios
```

Review the generated project diff before committing. CocoaPods output, Xcode user
state, and build products remain ignored. The project has a stable bundle identifier
(`com.bookshelf.ar.catalog`) that can be changed in `app.json` before regenerating.

An iOS Simulator can confirm that the custom module is linked and that unsupported
hardware states are handled, but it cannot create a camera-based `ARWorldMap`. Map,
place, and relocalize shelves on a physical iPhone 12 or newer. The physical-device
AR pass requires camera permission and, when saving shelf context, location permission.
The Linux workspace cannot run an iOS build; hardware validation remains a macOS/iPhone
step.

## Product flows

1. Add a book by scanning an EAN-13/EAN-8 ISBN or entering it manually.
2. Confirm or edit the metadata before saving.
3. Set up a named bookcase level.
4. Search the catalog and open book details without AR.
5. Locate a placed book from its details.

## ARKit implementation

The iOS-only local Expo module uses ARKit world tracking and a locally persisted
`ARWorldMap`, with RealityKit rendering book markers. Setting the shelf origin creates
the named `bookshelf-origin` anchor, archives a separate world map per bookcase in
Application Support, and stores its map identifier in the local library state. Book
positions are hit-tested and stored in meters relative to that bookcase anchor, so each
bookcase can restore independently after relaunch. During locate, ARKit restores the
selected book’s shelf map and reports whether that shelf was found; users can re-scan
when relocalization fails. Replacing a shelf map requires confirmation and clears only
that shelf’s old book positions because they are tied to the previous origin.

The **Set shelf origin** action remains disabled until ARKit reports both normal
tracking and a mapped world map. This prevents saving a fragile anchor while the phone
has only just started tracking; aim the center of the view at the shelf, then pan the
full level slowly in even light.

The native module is deliberately iOS-only. Android is intentionally deferred until a
separate local relocalization spike is completed.

## Metadata behavior

Open Library is the primary source. The user can edit title, author, publisher,
subjects, description, and cover information before saving. Missing metadata does not
block saving when the required ISBN, title, and author are present. ISBN-10 entries
(including an `X` check digit) are validated and stored as canonical ISBN-13 values,
so scanning either ISBN form updates the same catalog item.

## Validation

```bash
pnpm --filter @workspace/bookshelf-ar-catalog run typecheck
```

To create and serve a local static Expo build:

```bash
BASE_URL=http://localhost:3000 pnpm run app:build
pnpm run app:serve
```

The build script starts a separate Metro process on port 8081 by default. Override
`EXPO_METRO_PORT` or `PORT` when those ports are already in use.

The workspace-wide check is also available:

```bash
pnpm run typecheck
```

Manual acceptance testing must cover camera denial, invalid ISBNs, unknown ISBNs,
offline/manual entry, repeat ISBN scans, shelf setup, persistence after reopening,
search, and AR relocalization on an iPhone 12 or newer. For the AR pass: map a shelf,
place a book, force-close the app, relaunch it in front of the same shelf, then confirm
that the marker returns. Repeat with a different shelf in view and confirm the app
clearly offers to re-scan rather than claiming the shelf was found.