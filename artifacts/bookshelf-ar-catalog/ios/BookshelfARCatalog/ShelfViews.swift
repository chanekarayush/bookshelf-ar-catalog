import ARKit
import SwiftUI

struct ShelfSetupView: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var router: AppRouter
    @StateObject private var locationService = LocationService()
    @State private var controller = ShelfARController()
    @State private var status = ARTrackingStatus(status: .scanning, message: "Move across the shelf until the map is ready to save.")
    @State private var shelfName = ""
    @State private var saving = false
    @State private var showingReplaceConfirmation = false
    @State private var alertMessage: String?
    let shelfID: String

    private var shelf: Shelf {
        store.shelves.first(where: { $0.id == shelfID }) ?? store.activeShelf
    }

    private var arSupported: Bool {
        UIDevice.current.userInterfaceIdiom == .phone && ARWorldTrackingConfiguration.isSupported
    }

    private var readyToSave: Bool {
        arSupported && status.status == .readyToPlace
    }

    var body: some View {
        Screen {
            VStack(spacing: 12) {
                Image(systemName: "square.3.layers.3d")
                    .font(.system(size: 38))
                    .foregroundStyle(Brand.primary)
                Text(shelf.mapped ? "Re-scan your shelf" : "Map your bookcase level")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("Pan across the full level in even light. The saved world map lets ARKit find this shelf after relaunch.")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(Brand.mutedForeground)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(Brand.accent, in: RoundedRectangle(cornerRadius: 22))

            if arSupported {
                ShelfARView(controller: controller)
                    .frame(height: 250)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(alignment: .bottom) {
                        HStack(spacing: 8) {
                            Circle().fill(readyToSave ? Brand.primary : Brand.mutedForeground).frame(width: 8, height: 8)
                            Text(status.message)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .lineLimit(2)
                            Spacer()
                        }
                        .padding(12)
                        .background(Brand.card.opacity(0.95), in: RoundedRectangle(cornerRadius: 14))
                        .padding(12)
                    }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "iphone").font(.title2).foregroundStyle(Brand.primary)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Native iOS build required").font(.system(size: 14, weight: .bold, design: .rounded))
                        Text("Build the app for an iPhone 12 or newer to scan and save a real ARKit world map.")
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Brand.mutedForeground)
                    }
                }
                .padding(16)
                .background(Brand.secondary, in: RoundedRectangle(cornerRadius: 18))
            }

            FormField(label: "Shelf name", text: $shelfName, placeholder: "Living room bookcase")
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: "mappin.and.ellipse").foregroundStyle(Brand.primary)
                Text(shelf.location == nil ? "GPS helps identify the right room or area; AR handles the exact shelf position." : "A GPS area is saved. AR will handle the exact shelf position.")
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Brand.mutedForeground)
            }
            .padding(12)
            .background(Brand.secondary, in: RoundedRectangle(cornerRadius: 15))
            VStack(alignment: .leading, spacing: 16) {
                InstructionStep(number: "1", text: "Pan slowly across the bookcase")
                InstructionStep(number: "2", text: "Wait for the scan to be ready")
                InstructionStep(number: "3", text: "Save the shelf origin")
            }
            .padding(16)
            .overlay(RoundedRectangle(cornerRadius: 17).stroke(Brand.border))

            Button {
                if shelf.mapped {
                    showingReplaceConfirmation = true
                } else {
                    save()
                }
            } label: {
                HStack {
                    Image(systemName: readyToSave ? "scope" : "lock")
                    Text(!arSupported ? "Native iOS build required" : status.status == .unavailable ? "ARKit unavailable" : saving ? "Saving shelf…" : readyToSave ? (shelf.mapped ? "Replace shelf map" : "Set shelf origin") : "Scanning shelf…")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!readyToSave || saving)
            .opacity(readyToSave && !saving ? 1 : 0.55)
        }
        .navigationTitle("Shelf setup")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            shelfName = shelf.name
            controller.mode = .scan
            controller.shelfID = shelf.id
            controller.statusHandler = { status in
                self.status = status
            }
        }
        .onDisappear { controller.stop() }
        .confirmationDialog(
            "Replace shelf map?",
            isPresented: $showingReplaceConfirmation,
            titleVisibility: .visible
        ) {
            Button("Replace and clear positions", role: .destructive) { save() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Replacing this shelf map clears all saved book positions because they are tied to the current shelf origin.")
        }
        .alert("Shelf not saved", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) { alertMessage = nil }
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private func save() {
        guard !shelfName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            alertMessage = "Give this bookcase level a name."
            return
        }
        saving = true
        let gpsTask = Task { await locationService.capture() }
        Task {
            let result = await controller.saveShelfOrigin(for: shelf.id)
            guard result.saved, let mapID = result.mapID else {
                await MainActor.run {
                    saving = false
                    alertMessage = result.reason == "tracking-not-ready"
                        ? "Move slowly until ARKit says the shelf scan is ready, then try again."
                        : "Keep the bookcase in view and try scanning again."
                }
                return
            }
            await MainActor.run {
                store.setupShelf(shelf.id, name: shelfName.trimmingCharacters(in: .whitespacesAndNewlines), worldMapID: mapID)
                saving = false
                router.path = NavigationPath()
                router.selectedTab = 0
            }
            let gps = await gpsTask.value
            if let location = gps.location {
                await MainActor.run {
                    store.setShelfLocation(location, for: shelf.id, worldMapID: mapID)
                }
            }
        }
    }
}

private struct InstructionStep: View {
    let number: String
    let text: String
    var body: some View {
        HStack(spacing: 12) {
            Text(number)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(Brand.primary, in: Circle())
            Text(text).font(.system(size: 14, design: .rounded))
        }
    }
}

struct LocateBookView: View {
    @EnvironmentObject private var store: LibraryStore
    @EnvironmentObject private var router: AppRouter
    @StateObject private var locationService = LocationService()
    @State private var controller = ShelfARController()
    @State private var status = ARTrackingStatus(status: .searching, message: "Searching for the saved shelf map.")
    @State private var gpsState: GPSState = .ready
    @State private var distance: Double?
    @State private var arStarted = false
    @State private var alertMessage: String?
    let bookID: String
    let placing: Bool

    private var book: Book? { store.books.first(where: { $0.id == bookID }) }
    private var bookShelf: Shelf? {
        guard let book else { return nil }
        return store.shelves.first(where: { $0.id == book.shelfID }) ?? store.activeShelf
    }

    enum GPSState {
        case ready, checking, near, far, notSaved, denied, unavailable
    }

    var body: some View {
        Group {
            if let book, let shelf = bookShelf {
                VStack(spacing: 0) {
                    ZStack(alignment: .top) {
                        if !arStarted {
                            GPSGate(state: gpsState, distance: distance) {
                                checkGPS(shelf: shelf)
                            } openAR: {
                                arStarted = true
                            }
                        } else if shelf.mapped {
                            ShelfARView(controller: controller)
                                .ignoresSafeArea(edges: .top)
                                .overlay(alignment: .top) {
                                    Text(status.message)
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Brand.card.opacity(0.92), in: Capsule())
                                        .padding(.top, 14)
                                }
                        } else {
                            FallbackCard(title: "Map this shelf first", text: "Scan and save this shelf on an iPhone before placing or locating books.")
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(.black)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(placing ? "PLACE THIS BOOK" : "YOU’RE LOOKING FOR")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .tracking(1.5)
                            .foregroundStyle(Brand.mutedForeground)
                        Text(book.title).font(.system(size: 23, weight: .bold, design: .rounded))
                        Text(book.authors).font(.system(size: 14, design: .rounded)).foregroundStyle(Brand.mutedForeground)
                        Text(note(for: shelf))
                            .font(.system(size: 13, design: .rounded))
                            .foregroundStyle(Brand.mutedForeground)
                            .padding(.top, 5)
                        Button("Done") { router.resetTo(.bookDetail(book.id)) }
                            .buttonStyle(PrimaryButtonStyle())
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 22)
                    .padding(.bottom, 18)
                    .background(Brand.background)
                }
            } else {
                Text("Book not found.")
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard let shelf = bookShelf else { return }
            if shelf.location == nil { gpsState = .notSaved; arStarted = true }
            controller.mode = placing ? .place : .locate
            controller.shelfID = shelf.id
            controller.selectedBookID = book?.id
            controller.placements = store.books.filter { $0.shelfID == shelf.id && $0.placement != nil }.compactMap {
                guard let placement = $0.placement else { return nil }
                return PlacementRecord(id: $0.id, x: placement.x, y: placement.y, z: placement.z)
            }
            controller.statusHandler = { self.status = $0 }
            controller.placementHandler = { id, placement in
                store.placeBook(id, at: placement)
                status = ARTrackingStatus(status: .placed, message: "This position is saved locally with the shelf map.")
            }
        }
        .onChange(of: arStarted) { _, started in
            if started { controller.start() }
        }
        .onDisappear { controller.stop() }
    }

    private func checkGPS(shelf: Shelf) {
        guard let saved = shelf.location else {
            gpsState = .notSaved
            arStarted = true
            return
        }
        gpsState = .checking
        Task {
            let result = await locationService.capture()
            await MainActor.run {
                if result.status == .denied {
                    gpsState = .denied
                    arStarted = true
                } else if let current = result.location {
                    distance = LocationMath.distanceInMeters(from: saved, to: current)
                    gpsState = LocationMath.isNear(distance: distance!, savedAccuracy: saved.accuracy, currentAccuracy: current.accuracy) ? .near : .far
                } else {
                    gpsState = .unavailable
                    arStarted = true
                }
            }
        }
    }

    private func note(for shelf: Shelf) -> String {
        if !shelf.mapped { return "Map this shelf on an iPhone before placing or locating books." }
        switch gpsState {
        case .denied: return "GPS permission was denied. AR can still locate this shelf."
        case .unavailable: return "GPS is unavailable. AR can still locate this shelf."
        case .notSaved: return "No GPS area was saved. AR will try to locate this shelf directly."
        case .near where distance != nil: return "GPS says you are \(LocationMath.formatDistance(distance!)) from this shelf."
        default: return status.message
        }
    }
}

private struct GPSGate: View {
    let state: LocateBookView.GPSState
    let distance: Double?
    let check: () -> Void
    let openAR: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: state == .checking ? "mappin.and.ellipse" : "location")
                .font(.system(size: 34)).foregroundStyle(Brand.primary)
            Text(title).font(.system(size: 20, weight: .bold, design: .rounded))
            Text(message).font(.system(size: 14, design: .rounded)).foregroundStyle(Brand.mutedForeground).multilineTextAlignment(.center)
            if state == .ready {
                Button("Check shelf area", action: check).buttonStyle(PrimaryButtonStyle())
                Button("Open AR without GPS", action: openAR)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(Brand.secondary, in: RoundedRectangle(cornerRadius: 14))
            } else if state == .checking {
                Button("Skip GPS and open AR", action: openAR)
                    .buttonStyle(PrimaryButtonStyle())
            } else {
                Button("Open AR locator", action: openAR).buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(24)
        .background(Brand.card, in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Brand.border))
        .padding(22)
    }

    private var title: String {
        switch state {
        case .ready: return "Check your shelf area"
        case .checking: return "Checking your shelf area"
        case .near: return "You’re near this shelf"
        default: return "This shelf is farther away"
        }
    }

    private var message: String {
        switch state {
        case .ready: return "Use GPS to confirm the right room or area before opening AR. You can skip this step."
        case .checking: return "Waiting briefly for a GPS reading. You can open AR at any time."
        case .near, .far: return distance.map(LocationMath.formatDistance) ?? "Area check complete."
        case .denied: return "Location access is needed for this room-level check."
        case .unavailable: return "Location is unavailable. You can still open AR here."
        case .notSaved: return "No GPS area was saved. You can still open AR directly."
        }
    }
}

private struct FallbackCard: View {
    let title: String
    let text: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "layers").font(.system(size: 32)).foregroundStyle(Brand.primary)
            Text(title).font(.system(size: 18, weight: .bold, design: .rounded))
            Text(text).font(.system(size: 14, design: .rounded)).foregroundStyle(Brand.mutedForeground).multilineTextAlignment(.center)
        }
        .padding(24)
        .background(Brand.secondary, in: RoundedRectangle(cornerRadius: 22))
        .padding(22)
    }
}
