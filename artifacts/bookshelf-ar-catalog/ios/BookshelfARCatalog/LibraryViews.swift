import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var router: AppRouter

    var body: some View {
        Screen {
            if !store.hydrated {
                ProgressView().frame(maxWidth: .infinity, minHeight: 300)
            } else {
                HStack(spacing: 8) {
                    Circle().fill(Brand.primary).frame(width: 8, height: 8)
                    Text("YOUR READING ROOM")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(Brand.mutedForeground)
                }
                Text("Find your books,\nwithout the hunt.")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .tracking(-1)
                    .foregroundStyle(.primary)
                Text("A quiet catalog for the books you own and the shelf they call home.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Brand.mutedForeground)
                Button {
                    router.go(.addBook)
                } label: {
                    Label("Add a book", systemImage: "plus")
                }
                .buttonStyle(PrimaryButtonStyle())

                shelfCard
                HStack {
                    Text("Recently added")
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                    Spacer()
                    Button("See all") { router.selectedTab = 1 }
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Brand.primary)
                }
                ForEach(Array(store.books.prefix(2))) { book in
                    BookRow(book: book) { router.go(.bookDetail(book.id)) }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var shelfCard: some View {
        let placed = store.books.filter { $0.placement != nil }.count
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "square.3.layers.3d")
                    .foregroundStyle(Brand.primary)
                    .frame(width: 42, height: 42)
                    .background(Brand.accent, in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 3) {
                    Text("ACTIVE SHELF")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1)
                        .foregroundStyle(Brand.mutedForeground)
                    Text(store.activeShelf.name)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                }
                Spacer()
                Button {
                    router.go(.shelfSetup(store.activeShelf.id))
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Brand.mutedForeground)
                }
                .accessibilityLabel("Shelf settings")
            }
            GeometryReader { proxy in
                Capsule()
                    .fill(Brand.border)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .fill(Brand.primary)
                            .frame(width: proxy.size.width * min(1, CGFloat(placed) / CGFloat(max(store.books.count, 1))))
                    }
            }
            .frame(height: 6)
            HStack {
                Text("\(placed) of \(store.books.count) placed · \(store.activeShelf.location == nil ? "GPS not set" : "GPS saved")")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Brand.mutedForeground)
                Spacer()
                Button(store.activeShelf.mapped ? "Re-scan shelf" : "Set up shelf") {
                    router.go(.shelfSetup(store.activeShelf.id))
                }
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Brand.primary)
            }
        }
        .padding(16)
        .background(Brand.card, in: RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Brand.border))
    }
}

struct CatalogView: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var router: AppRouter
    @State private var query = ""

    private var results: [Book] {
        store.books.filter {
            "\($0.title) \($0.authors) \($0.subjects)"
                .localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        Screen {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("YOUR LIBRARY")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(Brand.primary)
                    Text("Catalog")
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                }
                Spacer()
                Button {
                    router.go(.addBook)
                } label: {
                    Image(systemName: "plus")
                        .foregroundStyle(.white)
                        .frame(width: 45, height: 45)
                        .background(Brand.primary, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass").foregroundStyle(Brand.mutedForeground)
                TextField("Search title, author, or subject", text: $query)
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 14)
            .frame(height: 50)
            .background(Brand.card, in: RoundedRectangle(cornerRadius: 15))
            .overlay(RoundedRectangle(cornerRadius: 15).stroke(Brand.border))
            Text("\(results.count) \(results.count == 1 ? "book" : "books")")
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Brand.mutedForeground)
            if results.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "book.closed").font(.system(size: 28)).foregroundStyle(Brand.primary)
                    Text("No books found").font(.system(size: 18, weight: .bold, design: .rounded))
                    Text("Try another search or add a new book.")
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Brand.mutedForeground)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 85)
            } else {
                ForEach(results) { book in
                    BookRow(book: book) { router.go(.bookDetail(book.id)) }
                }
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct BookRow: View {
    let book: Book
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                BookCoverView(url: book.coverURL, title: book.title)
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                        .lineLimit(1)
                        .foregroundStyle(.primary)
                    Text(book.authors)
                        .font(.system(size: 13, design: .rounded))
                        .foregroundStyle(Brand.mutedForeground)
                        .lineLimit(1)
                    Text(book.placement == nil ? (book.shelfID == nil ? "Not assigned" : "Needs placement") : "Placed on shelf")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(book.placement == nil ? Brand.mutedForeground : Brand.primary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Brand.mutedForeground)
            }
        }
        .buttonStyle(.plain)
    }
}

struct BookDetailView: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var router: AppRouter
    let bookID: String

    private var book: Book? { store.books.first(where: { $0.id == bookID }) }

    var body: some View {
        Screen {
            if let book {
                VStack(spacing: 8) {
                    BookCoverView(url: book.coverURL, title: book.title, size: 150)
                    Text(book.title)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .multilineTextAlignment(.center)
                    Text(book.authors)
                        .font(.system(size: 14, design: .rounded))
                        .foregroundStyle(Brand.mutedForeground)
                }
                .frame(maxWidth: .infinity)
                Button {
                    if book.shelfID == nil {
                        router.go(.assignBook(book.id))
                    } else if book.placement == nil {
                        router.go(.locateBook(book.id, placing: true))
                    } else {
                        router.go(.locateBook(book.id, placing: false))
                    }
                } label: {
                    Label(
                        book.shelfID == nil ? "Assign to bookcase" : (book.placement == nil ? "Place on shelf" : "Locate on shelf"),
                        systemImage: book.shelfID == nil ? "square.3.layers.3d" : (book.placement == nil ? "scope" : "location")
                    )
                }
                .buttonStyle(PrimaryButtonStyle())
                VStack(spacing: 14) {
                    DetailRow(label: "ISBN", value: book.isbn)
                    DetailRow(label: "Publisher", value: book.publisher.isEmpty ? "Not added" : book.publisher)
                    DetailRow(label: "Subjects", value: book.subjects.isEmpty ? "Not added" : book.subjects)
                }
                .padding(15)
                .background(RoundedRectangle(cornerRadius: 17).stroke(Brand.border))
                Text(book.description.isEmpty ? "No description added yet." : book.description)
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Brand.mutedForeground)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text("Book not found.")
            }
        }
        .navigationTitle("Book details")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(Brand.mutedForeground)
            Spacer()
            Text(value).font(.system(size: 13, design: .rounded)).multilineTextAlignment(.trailing)
        }
    }
}
