import Foundation

struct Placement: Codable, Equatable {
    var x: Float
    var y: Float
    var z: Float
}

struct ShelfLocation: Codable, Equatable {
    var latitude: Double
    var longitude: Double
    var accuracy: Double?
    var capturedAt: String
}

struct Book: Codable, Identifiable, Equatable {
    var id: String
    var isbn: String
    var title: String
    var authors: String
    var publisher: String
    var subjects: String
    var description: String
    var coverURL: String?
    var shelfID: String?
    var placement: Placement?
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id, isbn, title, authors, publisher, subjects, description, updatedAt
        case coverURL = "coverUrl"
        case shelfID = "shelfId"
        case placement
    }
}

struct Shelf: Codable, Identifiable, Equatable {
    var id: String
    var name: String
    var mapped: Bool
    var worldMapID: String? = nil
    var lastMappedAt: String? = nil
    var location: ShelfLocation? = nil

    enum CodingKeys: String, CodingKey {
        case id, name, mapped, location
        case worldMapID = "worldMapId"
        case lastMappedAt = "lastMappedAt"
    }

    init(
        id: String,
        name: String,
        mapped: Bool,
        worldMapID: String? = nil,
        lastMappedAt: String? = nil,
        location: ShelfLocation? = nil
    ) {
        self.id = id
        self.name = name
        self.mapped = mapped
        self.worldMapID = worldMapID
        self.lastMappedAt = lastMappedAt
        self.location = location
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id) ?? "shelf-default"
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "Living room bookcase"
        mapped = try container.decodeIfPresent(Bool.self, forKey: .mapped) ?? false
        worldMapID = try container.decodeIfPresent(String.self, forKey: .worldMapID)
        lastMappedAt = try container.decodeIfPresent(String.self, forKey: .lastMappedAt)
        location = try container.decodeIfPresent(ShelfLocation.self, forKey: .location)
    }
}

struct LibrarySnapshot: Codable {
    var books: [Book]
    var shelves: [Shelf]
    var activeShelfID: String
    // Kept for compatibility with the previous AsyncStorage snapshot.
    var shelf: Shelf?

    enum CodingKeys: String, CodingKey {
        case books, shelves, shelf
        case activeShelfID = "activeShelfId"
    }

    init(books: [Book], shelves: [Shelf], activeShelfID: String, shelf: Shelf?) {
        self.books = books
        self.shelves = shelves
        self.activeShelfID = activeShelfID
        self.shelf = shelf
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        books = try container.decodeIfPresent([Book].self, forKey: .books) ?? []
        shelves = try container.decodeIfPresent([Shelf].self, forKey: .shelves) ?? []
        activeShelfID = try container.decodeIfPresent(String.self, forKey: .activeShelfID) ?? ""
        shelf = try container.decodeIfPresent(Shelf.self, forKey: .shelf)
    }
}

enum ISBN {
    static func canonicalize(_ value: String) -> String? {
        let normalized = value
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")
            .uppercased()

        if isValidISBN13(normalized) {
            return normalized
        }

        guard normalized.count == 10 else { return nil }
        let characters = Array(normalized)
        guard characters.dropLast().allSatisfy({ $0.isNumber }),
              characters.last?.isNumber == true || characters.last == "X" else {
            return nil
        }

        let checksum = characters.enumerated().reduce(0) { total, item in
            let value = item.element == "X" ? 10 : Int(String(item.element))!
            return total + value * (10 - item.offset)
        }
        guard checksum % 11 == 0 else { return nil }

        let prefix = "978" + String(normalized.prefix(9))
        return prefix + isbn13CheckDigit(prefix)
    }

    private static func isValidISBN13(_ value: String) -> Bool {
        guard value.count == 13, value.allSatisfy(\.isNumber) else { return false }
        let digits = value.compactMap { Int(String($0)) }
        let sum = digits.prefix(12).enumerated().reduce(0) { total, item in
            total + item.element * (item.offset.isMultiple(of: 2) ? 1 : 3)
        }
        return (10 - (sum % 10)) % 10 == digits[12]
    }

    private static func isbn13CheckDigit(_ firstTwelve: String) -> String {
        let digits = firstTwelve.compactMap { Int(String($0)) }
        let sum = digits.enumerated().reduce(0) { total, item in
            total + item.element * (item.offset.isMultiple(of: 2) ? 1 : 3)
        }
        return String((10 - (sum % 10)) % 10)
    }
}

enum AppDate {
    static func nowISO8601() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
