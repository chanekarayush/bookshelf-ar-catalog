import Foundation
import SwiftUI

@MainActor
final class LibraryStore: ObservableObject {
    static let storageKey = "bookshelf-ar-catalog:v1"

    @Published private(set) var books: [Book] = []
    @Published private(set) var shelves: [Shelf] = []
    @Published var activeShelfID: String = "shelf-default"
    @Published private(set) var hydrated = false

    var activeShelf: Shelf {
        shelves.first(where: { $0.id == activeShelfID })
            ?? shelves.first
            ?? Self.defaultShelf
    }

    static let defaultShelf = Shelf(
        id: "shelf-default",
        name: "Living room bookcase",
        mapped: false,
        worldMapID: nil,
        lastMappedAt: nil,
        location: nil
    )

    static let demoBooks: [Book] = [
        Book(
            id: "demo-1",
            isbn: "9780140328721",
            title: "Fantastic Mr Fox",
            authors: "Roald Dahl",
            publisher: "Penguin",
            subjects: "Children, Fiction",
            description: "A quick-witted fox outsmarts three farmers.",
            coverURL: "https://covers.openlibrary.org/b/isbn/9780140328721-M.jpg",
            shelfID: "shelf-default",
            placement: nil,
            updatedAt: AppDate.nowISO8601()
        ),
        Book(
            id: "demo-2",
            isbn: "9780140449136",
            title: "The Odyssey",
            authors: "Homer",
            publisher: "Penguin Classics",
            subjects: "Classics, Poetry",
            description: "Odysseus journeys home after the Trojan War.",
            coverURL: "https://covers.openlibrary.org/b/isbn/9780140449136-M.jpg",
            shelfID: "shelf-default",
            placement: nil,
            updatedAt: AppDate.nowISO8601()
        )
    ]

    init() {
        load()
    }

    func saveBook(_ input: BookInput) throws -> Book {
        guard let isbn = ISBN.canonicalize(input.isbn) else {
            throw LibraryError.invalidISBN
        }
        guard !input.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !input.authors.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LibraryError.missingRequiredMetadata
        }

        let existing = books.first(where: { ISBN.canonicalize($0.isbn) == isbn })
            ?? input.id.flatMap { id in books.first(where: { $0.id == id }) }
        let saved = Book(
            id: existing?.id ?? input.id ?? UUID().uuidString,
            isbn: isbn,
            title: input.title.trimmingCharacters(in: .whitespacesAndNewlines),
            authors: input.authors.trimmingCharacters(in: .whitespacesAndNewlines),
            publisher: input.publisher,
            subjects: input.subjects,
            description: input.description,
            coverURL: input.coverURL,
            shelfID: input.shelfID ?? existing?.shelfID,
            placement: input.placement ?? existing?.placement,
            updatedAt: AppDate.nowISO8601()
        )

        if let index = books.firstIndex(where: { $0.id == saved.id }) {
            books[index] = saved
        } else {
            books.insert(saved, at: 0)
        }
        persist()
        return saved
    }

    func placeBook(_ bookID: String, at placement: Placement) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[index].placement = placement
        books[index].updatedAt = AppDate.nowISO8601()
        persist()
    }

    func assignBook(_ bookID: String, to shelfID: String) {
        guard let index = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[index].shelfID = shelfID
        books[index].placement = nil
        books[index].updatedAt = AppDate.nowISO8601()
        activeShelfID = shelfID
        persist()
    }

    @discardableResult
    func createShelf(name: String, assigning bookID: String? = nil) -> Shelf {
        let newShelf = Shelf(id: UUID().uuidString, name: name, mapped: false)
        shelves.append(newShelf)
        if let bookID {
            assignBook(bookID, to: newShelf.id)
        } else {
            activeShelfID = newShelf.id
            persist()
        }
        return newShelf
    }

    func setupShelf(_ shelfID: String, name: String, worldMapID: String) {
        guard let index = shelves.firstIndex(where: { $0.id == shelfID }) else { return }
        let oldShelf = shelves[index]
        let replacingMap = oldShelf.mapped && oldShelf.worldMapID != worldMapID
        shelves[index] = Shelf(
            id: oldShelf.id,
            name: name,
            mapped: true,
            worldMapID: worldMapID,
            lastMappedAt: AppDate.nowISO8601(),
            location: nil
        )
        if replacingMap {
            for bookIndex in books.indices where books[bookIndex].shelfID == shelfID {
                books[bookIndex].placement = nil
                books[bookIndex].updatedAt = AppDate.nowISO8601()
            }
        }
        activeShelfID = shelfID
        persist()
    }

    func setShelfLocation(_ location: ShelfLocation, for shelfID: String, worldMapID: String) {
        guard let index = shelves.firstIndex(where: {
            $0.id == shelfID && $0.worldMapID == worldMapID
        }) else { return }
        shelves[index].location = location
        persist()
    }

    private func load() {
        defer { hydrated = true }
        let data = UserDefaults.standard.data(forKey: Self.storageKey)
            ?? LegacyAsyncStorage.snapshotData(forKey: Self.storageKey)
        guard let data else {
            books = Self.demoBooks
            shelves = [Self.defaultShelf]
            activeShelfID = Self.defaultShelf.id
            return
        }

        do {
            let saved = try JSONDecoder().decode(LibrarySnapshot.self, from: data)
            let legacyShelf = saved.shelf ?? Self.defaultShelf
            shelves = saved.shelves.isEmpty ? [legacyShelf] : saved.shelves
            let defaultShelfID = shelves[0].id
            books = saved.books.map { book in
                var migrated = book
                if migrated.shelfID == nil {
                    migrated.shelfID = defaultShelfID
                }
                return migrated
            }
            activeShelfID = saved.activeShelfID.isEmpty ? defaultShelfID : saved.activeShelfID
            persist()
        } catch {
            books = Self.demoBooks
            shelves = [Self.defaultShelf]
            activeShelfID = Self.defaultShelf.id
        }
    }

    private func persist() {
        let snapshot = LibrarySnapshot(
            books: books,
            shelves: shelves,
            activeShelfID: activeShelfID,
            shelf: shelves.first(where: { $0.id == activeShelfID }) ?? shelves.first
        )
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: Self.storageKey)
    }
}

private enum LegacyAsyncStorage {
    static func snapshotData(forKey key: String) -> Data? {
        let fileManager = FileManager.default
        let roots = [
            fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first,
            fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        ].compactMap { $0 }
        let directories = roots.flatMap {
            [
                $0.appendingPathComponent("RCTAsyncLocalStorage_V1", isDirectory: true),
                $0.appendingPathComponent("AsyncStorage", isDirectory: true)
            ]
        }

        for directory in directories where fileManager.fileExists(atPath: directory.path) {
            let manifest = directory.appendingPathComponent("manifest.json")
            if let data = try? Data(contentsOf: manifest),
               let values = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let serialized = values[key] as? String,
               let snapshot = serialized.data(using: .utf8),
               isLibrarySnapshot(snapshot) {
                return snapshot
            }

            guard let files = try? fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ) else { continue }
            for file in files where file.lastPathComponent != "manifest.json" {
                guard let candidate = try? Data(contentsOf: file), isLibrarySnapshot(candidate) else {
                    continue
                }
                return candidate
            }
        }
        return nil
    }

    private static func isLibrarySnapshot(_ data: Data) -> Bool {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return false
        }
        return object["books"] is [Any]
    }
}

struct BookInput {
    var id: String?
    var isbn: String
    var title: String
    var authors: String
    var publisher: String
    var subjects: String
    var description: String
    var coverURL: String?
    var shelfID: String?
    var placement: Placement?
}

enum LibraryError: LocalizedError {
    case invalidISBN
    case missingRequiredMetadata

    var errorDescription: String? {
        switch self {
        case .invalidISBN:
            return "A valid ISBN-10 or ISBN-13 is required."
        case .missingRequiredMetadata:
            return "A title and author are required before saving."
        }
    }
}
