import SwiftUI

private struct BookForm {
    var isbn = ""
    var title = ""
    var authors = ""
    var publisher = ""
    var subjects = ""
    var description = ""
    var coverURL = ""
}

struct AddBookView: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var router: AppRouter
    @State private var form = BookForm()
    @State private var isLookingUp = false
    @State private var showingScanner = false
    @State private var alertMessage: String?
    private let client = OpenLibraryClient()

    var body: some View {
        Screen {
            Text("Start with the ISBN.")
                .font(.system(size: 31, weight: .bold, design: .rounded))
            Text("We’ll find the details, then you can make them yours.")
                .font(.system(size: 15, design: .rounded))
                .foregroundStyle(Brand.mutedForeground)
            Button {
                showingScanner = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 21))
                        .foregroundStyle(Brand.primary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Scan ISBN barcode").font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("On-device camera scan").font(.system(size: 12, design: .rounded)).foregroundStyle(Brand.mutedForeground)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(Brand.primary)
                }
                .foregroundStyle(.primary)
                .padding(15)
                .background(Brand.accent, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).stroke(Brand.primary))
            }
            DividerLabel(text: "or enter manually")
            FormField(label: "ISBN", text: $form.isbn, placeholder: "978-0-00-000000-0") {
                lookupIfValid()
            }
            FormField(label: "Title", text: $form.title, placeholder: "Book title")
            FormField(label: "Author", text: $form.authors, placeholder: "Author name")
            FormField(label: "Publisher / year", text: $form.publisher, placeholder: "Optional")
            FormField(label: "Subjects", text: $form.subjects, placeholder: "Optional, comma separated")
            VStack(alignment: .leading, spacing: 6) {
                Text("DESCRIPTION").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(Brand.mutedForeground)
                TextEditor(text: $form.description)
                    .frame(minHeight: 82)
                    .padding(8)
                    .background(Brand.card, in: RoundedRectangle(cornerRadius: 13))
                    .overlay(RoundedRectangle(cornerRadius: 13).stroke(Brand.border))
            }
            Button {
                save()
            } label: {
                isLookingUp ? AnyView(ProgressView().tint(.white)) : AnyView(Text("Save book"))
            }
            .disabled(isLookingUp)
            .buttonStyle(PrimaryButtonStyle())
            .opacity(isLookingUp ? 0.6 : 1)
        }
        .navigationTitle("Add a book")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingScanner) {
            ZStack(alignment: .topTrailing) {
                BarcodeScannerView { value in
                    showingScanner = false
                    scanned(value)
                } onDenied: {
                    showingScanner = false
                    alertMessage = "Allow camera access in Settings to scan ISBNs."
                }
                Button {
                    showingScanner = false
                } label: {
                    Image(systemName: "xmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(.black.opacity(0.55), in: Circle())
                }
                .padding(.top, 24)
                .padding(.trailing, 20)
            }
            .ignoresSafeArea()
        }
        .alert("Bookshelf AR Catalog", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func scanned(_ raw: String) {
        guard let isbn = ISBN.canonicalize(raw) else { return }
        form.isbn = isbn
        lookup(isbn)
    }

    private func lookupIfValid() {
        guard let isbn = ISBN.canonicalize(form.isbn) else { return }
        form.isbn = isbn
        lookup(isbn)
    }

    private func lookup(_ isbn: String) {
        isLookingUp = true
        Task {
            do {
                let result = try await client.lookup(isbn: isbn)
                form.title = result.title
                form.authors = result.authors
                form.publisher = result.publisher
                form.subjects = result.subjects
                form.coverURL = result.coverURL
            } catch {
                alertMessage = "Book not found. Enter the book details manually before saving."
            }
            isLookingUp = false
        }
    }

    private func save() {
        do {
            let book = try store.saveBook(BookInput(
                id: nil,
                isbn: form.isbn,
                title: form.title,
                authors: form.authors,
                publisher: form.publisher,
                subjects: form.subjects,
                description: form.description,
                coverURL: form.coverURL.isEmpty ? nil : form.coverURL,
                shelfID: nil,
                placement: nil
            ))
            router.go(.assignBook(book.id))
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}

struct AssignBookView: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var router: AppRouter
    let bookID: String
    @State private var addingBookcase = false
    @State private var newBookcaseName = ""

    private var book: Book? { store.books.first(where: { $0.id == bookID }) }

    var body: some View {
        Screen {
            if let book {
                Text("Where should it live?")
                    .font(.system(size: 31, weight: .bold, design: .rounded))
                Text("Choose a bookcase for \(book.title), or leave it unassigned for now.")
                    .font(.system(size: 15, design: .rounded))
                    .foregroundStyle(Brand.mutedForeground)
                Text("YOUR BOOKCASES")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .tracking(1.3)
                    .foregroundStyle(Brand.mutedForeground)
                ForEach(store.shelves) { shelf in
                    Button {
                        store.assignBook(book.id, to: shelf.id)
                        router.resetTo(.bookDetail(book.id))
                    } label: {
                        ShelfOption(shelf: shelf)
                    }
                    .buttonStyle(.plain)
                }

                if addingBookcase {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Add a new bookcase").font(.system(size: 15, weight: .bold, design: .rounded))
                        TextField("e.g. Study bookcase", text: $newBookcaseName)
                            .padding(.horizontal, 13)
                            .frame(height: 47)
                            .background(Brand.card, in: RoundedRectangle(cornerRadius: 13))
                            .overlay(RoundedRectangle(cornerRadius: 13).stroke(Brand.border))
                        HStack {
                            Spacer()
                            Button("Cancel") {
                                addingBookcase = false
                                newBookcaseName = ""
                            }
                            .foregroundStyle(Brand.mutedForeground)
                            Button("Add bookcase") {
                                let shelf = store.createShelf(name: newBookcaseName.trimmingCharacters(in: .whitespacesAndNewlines), assigning: book.id)
                                router.resetTo(.bookDetail(book.id))
                                router.selectedTab = 0
                                _ = shelf
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(Brand.primary)
                            .disabled(newBookcaseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(14)
                    .background(Brand.accent, in: RoundedRectangle(cornerRadius: 18))
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Brand.primary))
                } else {
                    Button {
                        addingBookcase = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "plus")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(Brand.primary, in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Add a new bookcase").font(.system(size: 15, weight: .bold, design: .rounded))
                                Text("Create a place for this and future books").font(.system(size: 12, design: .rounded)).foregroundStyle(Brand.mutedForeground)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Brand.primary)
                        }
                        .foregroundStyle(.primary)
                        .padding(13)
                        .background(Brand.accent, in: RoundedRectangle(cornerRadius: 17))
                        .overlay(RoundedRectangle(cornerRadius: 17).stroke(Brand.primary))
                    }
                }
                Button("Skip for now") {
                    router.resetTo(.bookDetail(book.id))
                }
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Brand.mutedForeground)
                .frame(maxWidth: .infinity)
            } else {
                Text("Book not found.")
            }
        }
        .navigationTitle("Bookcase")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ShelfOption: View {
    let shelf: Shelf

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "square.3.layers.3d")
                .foregroundStyle(Brand.primary)
                .frame(width: 40, height: 40)
                .background(Brand.accent, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(shelf.name).font(.system(size: 15, weight: .bold, design: .rounded))
                Text(shelf.mapped ? "Mapped and ready to locate books" : "Not mapped yet")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Brand.mutedForeground)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Brand.mutedForeground)
        }
        .foregroundStyle(.primary)
        .padding(13)
        .background(Brand.card, in: RoundedRectangle(cornerRadius: 17))
        .overlay(RoundedRectangle(cornerRadius: 17).stroke(Brand.border))
    }
}

private struct DividerLabel: View {
    let text: String
    var body: some View {
        HStack(spacing: 9) {
            Rectangle().fill(Brand.border).frame(height: 1)
            Text(text).font(.system(size: 11, design: .rounded)).foregroundStyle(Brand.mutedForeground)
            Rectangle().fill(Brand.border).frame(height: 1)
        }
    }
}

struct FormField: View {
    let label: String
    @Binding var text: String
    let placeholder: String
    var onCommit: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Brand.mutedForeground)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(label == "ISBN" ? .characters : .words)
                .submitLabel(.done)
                .onSubmit { onCommit?() }
                .padding(.horizontal, 14)
                .frame(height: 48)
                .background(Brand.card, in: RoundedRectangle(cornerRadius: 13))
                .overlay(RoundedRectangle(cornerRadius: 13).stroke(Brand.border))
        }
    }
}
