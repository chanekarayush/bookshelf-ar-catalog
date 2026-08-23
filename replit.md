# Bookshelf AR Catalog

Bookshelf AR Catalog helps a person catalog physical books and find them on one bookcase level.

## Run & Operate

- `pnpm --filter @workspace/api-server run dev` — run the API server (port 5000)
- `pnpm --filter @workspace/bookshelf-ar-catalog run dev` — run the Expo mobile preview
- `pnpm run typecheck` — full typecheck across all packages
- `pnpm run build` — typecheck + build all packages
- `pnpm --filter @workspace/api-spec run codegen` — regenerate API hooks and Zod schemas from the OpenAPI spec
- `pnpm --filter @workspace/db run push` — push DB schema changes (dev only)
- Required env: `DATABASE_URL` — Postgres connection string

## Stack

- pnpm workspaces, Node.js 24, TypeScript 5.9
- Mobile: Expo 54, React Native, Expo Router, TypeScript
- Persistence: AsyncStorage for the local-first MVP
- Native target: iOS ARKit/RealityKit bridge planned for iPhone 12+

## Where things live

- `artifacts/bookshelf-ar-catalog` — mobile app
- `artifacts/bookshelf-ar-catalog/context/LibraryContext.tsx` — local catalog and shelf state
- `artifacts/bookshelf-ar-catalog/app` — Expo Router screens
- `README.md` — scope, setup, AR boundary, and acceptance checklist

## Architecture decisions

- iOS is the required MVP platform; Android waits for a separate local relocalization spike.
- One normalized ISBN maps to one catalog item in this iteration; later versions can model physical copies.
- AR placement is deliberately isolated from catalog persistence so an AR failure never loses a confirmed book.
- AsyncStorage is used for the first mobile slice; no backend or account system is required.

## Product

The app scans ISBNs, retrieves editable Open Library metadata, stores a personal catalog
locally, lets the user name and map a bookcase level, and provides a locate flow for
placed books.

## User preferences

_Populate as you build — explicit user instructions worth remembering across sessions._

## Gotchas

- Native ARKit persistence must be verified on real iPhone 12+ hardware; the preview locate screen is not native AR.
- Expo camera permission is required for barcode scanning.

## Pointers

- See the `pnpm-workspace` skill for workspace structure, TypeScript setup, and package details
