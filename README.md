# Bookshelf AR Catalog

A local-first native iOS library app for scanning ISBNs, editing book metadata, mapping
one bookcase level, and locating books later with an ARKit marker.

## MVP scope

- iOS first, validated on iPhone 12 or newer
- One local user, one device, one bookcase level
- One catalog item per normalized ISBN
- Open Library lookup with editable metadata and manual fallback
- Local persistence with Codable data in UserDefaults
- Android intentionally deferred until local AR persistence and relocalization are proven

## Native iOS client

Open `artifacts/bookshelf-ar-catalog/ios/BookshelfARCatalog.xcodeproj` in Xcode
15 or later on macOS. Select the `BookshelfARCatalog` scheme, configure a signing
team, and run it on a physical iPhone 12 or newer. ARKit world mapping is not
available in the simulator. See `artifacts/bookshelf-ar-catalog/ios/README.md`
for the physical-device acceptance checklist.

## Product flows

1. Add a book by scanning an EAN-13/EAN-8 ISBN or entering it manually.
2. Confirm or edit the metadata before saving.
3. Set up a named bookcase level.
4. Search the catalog and open book details without AR.
5. Locate a placed book from its details.

## ARKit implementation

The native SwiftUI client uses ARKit world tracking and a locally persisted
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

The client is deliberately iOS-only. Android is intentionally deferred until a
separate local relocalization spike is completed.

## Metadata behavior

Open Library is the primary source. The user can edit title, author, publisher,
subjects, description, and cover information before saving. Missing metadata does not
block saving when the required ISBN, title, and author are present. ISBN-10 entries
(including an `X` check digit) are validated and stored as canonical ISBN-13 values,
so scanning either ISBN form updates the same catalog item.

## Validation

The Linux workspace cannot run Xcode or ARKit. Compile and run the native target
from Xcode on macOS, then cover camera denial, invalid ISBNs, unknown ISBNs,
offline/manual entry, repeat ISBN scans, shelf setup, persistence after reopening,
search, GPS fallbacks, and AR relocalization on an iPhone 12 or newer.