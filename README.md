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

## Run locally

```bash
pnpm install
pnpm --filter @workspace/bookshelf-ar-catalog run dev
```

Scan the Expo QR code from the Replit URL bar to open the app on a device. Camera
scanning requires camera permission. The current preview provides a working catalog,
search, metadata flow, shelf setup state, and locate UI; the native iOS ARKit bridge
is the next implementation slice.

## Product flows

1. Add a book by scanning an EAN-13/EAN-8 ISBN or entering it manually.
2. Confirm or edit the metadata before saving.
3. Set up a named bookcase level.
4. Search the catalog and open book details without AR.
5. Locate a placed book from its details.

## ARKit implementation boundary

The production iOS AR layer will use ARKit world tracking and a locally persisted
`ARWorldMap`, with RealityKit rendering the marker. The shared placement model stores
book positions relative to the shelf origin. A native capability spike must verify
world-map persistence and relocalization on iPhone 12+ before the feature is called
complete. The current locate screen is an explicit preview state, not a claim of
native AR accuracy.

## Metadata behavior

Open Library is the primary source. The user can edit title, author, publisher,
subjects, description, and cover information before saving. Missing metadata does not
block saving when the required ISBN, title, and author are present.

## Validation

```bash
pnpm --filter @workspace/bookshelf-ar-catalog run typecheck
```

Manual acceptance testing must cover camera denial, invalid ISBNs, unknown ISBNs,
offline/manual entry, repeat ISBN scans, shelf setup, persistence after reopening,
search, and AR relocalization on the supported iPhone target.