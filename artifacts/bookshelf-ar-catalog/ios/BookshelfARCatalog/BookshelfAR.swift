import ARKit
import RealityKit
import UIKit

struct ARTrackingStatus: Equatable {
    var status: Status
    var message: String

    enum Status: String {
        case scanning
        case searching
        case shelfFound = "shelf_found"
        case shelfNotFound = "shelf_not_found"
        case readyToPlace = "ready_to_place"
        case placed
        case limited
        case unavailable
    }
}

struct ARSaveResult {
    var saved: Bool
    var mapID: String?
    var reason: String?
}

enum BookshelfARPersistence {
    private static let directoryName = "BookshelfAR"

    private static func mapURL(for shelfID: String) -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let safeID = shelfID.unicodeScalars.map {
            CharacterSet.alphanumerics.contains($0) ? String($0) : "_"
        }.joined()
        return base
            .appendingPathComponent(directoryName)
            .appendingPathComponent("shelf-\(safeID).arexperience")
    }

    static func loadMap(for shelfID: String) throws -> ARWorldMap {
        let data = try Data(contentsOf: mapURL(for: shelfID))
        guard let map = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
            throw NSError(
                domain: "BookshelfAR",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "The saved shelf map could not be decoded."]
            )
        }
        return map
    }

    static func saveMap(_ map: ARWorldMap, for shelfID: String) throws {
        let url = mapURL(for: shelfID)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: false)
        try data.write(to: url, options: .atomic)
    }

    static func clearMap(for shelfID: String) throws {
        let url = mapURL(for: shelfID)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}

struct PlacementRecord: Decodable {
    var id: String
    var x: Float
    var y: Float
    var z: Float
}

final class ShelfARController: NSObject, ARSessionDelegate {
    let arView = ARView(frame: .zero)

    var mode: Mode = .scan {
        didSet {
            guard oldValue != mode else { return }
            updateMarkers()
            startSession()
        }
    }
    var shelfID = "shelf-default" {
        didSet {
            guard oldValue != shelfID else { return }
            originAnchor = nil
            markerAnchor.transform = Transform()
            updateMarkers()
            startSession()
        }
    }
    var selectedBookID: String? {
        didSet { updateMarkers() }
    }
    var placements: [PlacementRecord] = [] {
        didSet { updateMarkers() }
    }
    var statusHandler: ((ARTrackingStatus) -> Void)?
    var started = false

    enum Mode: Equatable {
        case scan
        case locate
        case place
    }

    private let markerAnchor = AnchorEntity(world: .zero)
    private var originAnchor: ARAnchor?
    private var markerEntities: [String: ModelEntity] = [:]
    private var relocalizationWorkItem: DispatchWorkItem?
    private var originSaveTimeout: DispatchWorkItem?
    private var pendingOriginAnchor: ARAnchor?
    private var pendingSave: CheckedContinuation<ARSaveResult, Never>?
    private var pendingSaveShelfID: String?
    private var pendingWorldMapSave: (continuation: CheckedContinuation<ARSaveResult, Never>, anchorID: UUID)?
    private var isWorldMapReady = false
    private var currentStatus: ARTrackingStatus.Status = .unavailable

    override init() {
        super.init()
        arView.backgroundColor = .black
        arView.session.delegate = self
        arView.automaticallyConfigureSession = false
        arView.scene.addAnchor(markerAnchor)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        arView.addGestureRecognizer(tap)
    }

    func start() {
        if !started { startSession() }
    }

    func stop() {
        relocalizationWorkItem?.cancel()
        resolveInFlightSave(reason: "ar-view-dismissed")
        arView.session.pause()
        started = false
    }

    func saveShelfOrigin(for requestedShelfID: String) async -> ARSaveResult {
        guard UIDevice.current.userInterfaceIdiom == .phone,
              ARWorldTrackingConfiguration.isSupported else {
            return ARSaveResult(saved: false, mapID: nil, reason: "iphone-12-or-newer-required")
        }
        guard mode == .scan, isWorldMapReady, isCameraTrackingNormally else {
            return ARSaveResult(saved: false, mapID: nil, reason: "tracking-not-ready")
        }
        guard requestedShelfID == shelfID else {
            return ARSaveResult(saved: false, mapID: nil, reason: "shelf-view-mismatch")
        }
        guard pendingSave == nil else {
            return ARSaveResult(saved: false, mapID: nil, reason: "shelf-save-in-progress")
        }

        let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
        let hit = arView.session.currentFrame?.hitTest(
            center,
            types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane, .featurePoint]
        ).first
        guard let hit else {
            publish(.limited, message: "Aim the center of the screen at the shelf until a surface is detected.")
            return ARSaveResult(saved: false, mapID: nil, reason: "shelf-surface-not-found")
        }

        return await withCheckedContinuation { continuation in
            let anchor = ARAnchor(name: "bookshelf-origin", transform: hit.worldTransform)
            originAnchor = anchor
            pendingOriginAnchor = anchor
            pendingSave = continuation
            pendingSaveShelfID = requestedShelfID
            let timeout = DispatchWorkItem { [weak self] in
                guard let self,
                      let pending = self.pendingSave,
                      self.pendingOriginAnchor?.identifier == anchor.identifier else { return }
                self.pendingSave = nil
                self.pendingSaveShelfID = nil
                self.pendingOriginAnchor = nil
                self.arView.session.remove(anchor: anchor)
                self.originAnchor = nil
                self.markerAnchor.transform = Transform()
                pending.resume(returning: ARSaveResult(saved: false, mapID: nil, reason: "anchor-not-added"))
                self.publish(.limited, message: "ARKit could not save the shelf anchor. Keep the shelf in view and try again.")
            }
            originSaveTimeout = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: timeout)
            arView.session.add(anchor: anchor)
        }
    }

    private func startSession() {
        relocalizationWorkItem?.cancel()
        resolveInFlightSave(reason: "ar-session-restarted")
        guard UIDevice.current.userInterfaceIdiom == .phone,
              ARWorldTrackingConfiguration.isSupported else {
            publish(.unavailable, message: "Shelf mapping requires an iPhone 12 or newer with ARKit world tracking.")
            return
        }

        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal, .vertical]
        configuration.environmentTexturing = .automatic
        if mode == .locate || mode == .place {
            do {
                configuration.initialWorldMap = try BookshelfARPersistence.loadMap(for: shelfID)
            } catch {
                started = false
                publish(.shelfNotFound, message: "This shelf has not been mapped on this device yet.")
                return
            }
        }

        originSaveTimeout?.cancel()
        isWorldMapReady = false
        originAnchor = nil
        markerAnchor.transform = Transform()
        started = true
        arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
        publish(
            mode == .scan ? .scanning : .searching,
            message: mode == .scan
                ? "Move across the shelf until the map is ready to save."
                : "Searching for the saved shelf map."
        )

        if mode == .locate || mode == .place {
            let timeout = DispatchWorkItem { [weak self] in
                guard let self, self.originAnchor == nil else { return }
                self.publish(.shelfNotFound, message: "The saved shelf could not be relocalized. Re-scan this shelf to continue.")
            }
            relocalizationWorkItem = timeout
            DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: timeout)
        }
    }

    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            if mode == .scan {
                publish(
                    isWorldMapReady ? .readyToPlace : .scanning,
                    message: isWorldMapReady
                        ? "Shelf map is ready. Aim at the shelf and save the origin."
                        : "Keep scanning until ARKit finishes building the shelf map."
                )
            } else if originAnchor != nil {
                publish(.shelfFound, message: "Shelf found. Keep the bookcase in view.")
            } else {
                publish(.searching, message: "Searching for the saved shelf map.")
            }
        case .limited(let reason):
            publish(.limited, message: trackingMessage(for: reason))
        case .notAvailable:
            publish(.unavailable, message: "ARKit tracking is not available right now.")
        @unknown default:
            publish(.limited, message: "Keep the shelf in view.")
        }
    }

    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard mode == .scan else { return }
        let mapIsReady = frame.worldMappingStatus == .mapped
        guard mapIsReady != isWorldMapReady else { return }
        isWorldMapReady = mapIsReady
        publish(
            mapIsReady && isCameraTrackingNormally ? .readyToPlace : .scanning,
            message: mapIsReady && isCameraTrackingNormally
                ? "Shelf map is ready. Aim at the shelf and save the origin."
                : mappingMessage(for: frame.worldMappingStatus)
        )
    }

    func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
        for anchor in anchors where anchor.name == "bookshelf-origin" {
            guard mode != .scan || pendingOriginAnchor?.identifier == anchor.identifier else {
                if mode == .scan { session.remove(anchor: anchor) }
                continue
            }
            relocalizationWorkItem?.cancel()
            originAnchor = anchor
            markerAnchor.transform = Transform(matrix: anchor.transform)
            updateMarkers()
            if mode == .scan, let pending = pendingSave, let saveShelfID = pendingSaveShelfID {
                self.pendingSave = nil
                self.pendingSaveShelfID = nil
                pendingOriginAnchor = nil
                originSaveTimeout?.cancel()
                saveCurrentWorldMap(pending, shelfID: saveShelfID, expectedAnchorID: anchor.identifier)
            }
            publish(mode == .scan ? .readyToPlace : .shelfFound, message: "Shelf origin found.")
        }
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        for anchor in anchors where anchor.name == "bookshelf-origin" {
            originAnchor = anchor
            markerAnchor.transform = Transform(matrix: anchor.transform)
        }
    }

    private func saveCurrentWorldMap(
        _ continuation: CheckedContinuation<ARSaveResult, Never>,
        shelfID: String,
        expectedAnchorID: UUID
    ) {
        guard isCameraTrackingNormally,
              arView.session.currentFrame?.worldMappingStatus == .mapped else {
            rejectSave(continuation, anchorID: expectedAnchorID, reason: "tracking-degraded-before-save")
            return
        }
        pendingWorldMapSave = (continuation, expectedAnchorID)
        arView.session.getCurrentWorldMap { [weak self] worldMap, error in
            DispatchQueue.main.async {
                guard let self,
                      self.pendingWorldMapSave?.anchorID == expectedAnchorID else { return }
                self.pendingWorldMapSave = nil
                guard let worldMap else {
                    self.rejectSave(
                        continuation,
                        anchorID: expectedAnchorID,
                        reason: error?.localizedDescription ?? "world-map-unavailable"
                    )
                    return
                }
                guard self.isCameraTrackingNormally,
                      self.arView.session.currentFrame?.worldMappingStatus == .mapped,
                      worldMap.anchors.contains(where: { $0.identifier == expectedAnchorID }) else {
                    self.rejectSave(continuation, anchorID: expectedAnchorID, reason: "world-map-not-ready")
                    return
                }
                do {
                    try BookshelfARPersistence.saveMap(worldMap, for: shelfID)
                    let mapID = UUID().uuidString
                    continuation.resume(returning: ARSaveResult(saved: true, mapID: mapID, reason: nil))
                    self.publish(.shelfFound, message: "Shelf origin saved on this device.")
                } catch {
                    continuation.resume(returning: ARSaveResult(saved: false, mapID: nil, reason: error.localizedDescription))
                }
            }
        }
    }

    private func rejectSave(
        _ continuation: CheckedContinuation<ARSaveResult, Never>,
        anchorID: UUID,
        reason: String
    ) {
        pendingWorldMapSave = nil
        if let anchor = originAnchor, anchor.identifier == anchorID {
            arView.session.remove(anchor: anchor)
            originAnchor = nil
            markerAnchor.transform = Transform()
        }
        continuation.resume(returning: ARSaveResult(saved: false, mapID: nil, reason: reason))
        publish(.limited, message: "ARKit could not save a stable shelf map. Keep the shelf in view and try again.")
    }

    private func resolveInFlightSave(reason: String) {
        originSaveTimeout?.cancel()
        originSaveTimeout = nil
        if let anchor = pendingOriginAnchor {
            arView.session.remove(anchor: anchor)
        }
        pendingOriginAnchor = nil
        originAnchor = nil
        markerAnchor.transform = Transform()
        if let pending = pendingSave {
            pendingSave = nil
            pendingSaveShelfID = nil
            pending.resume(returning: ARSaveResult(saved: false, mapID: nil, reason: reason))
        }
        if let worldMapSave = pendingWorldMapSave {
            pendingWorldMapSave = nil
            worldMapSave.continuation.resume(
                returning: ARSaveResult(saved: false, mapID: nil, reason: reason)
            )
        }
    }

    private func updateMarkers() {
        let visible = mode == .locate && selectedBookID != nil
            ? placements.filter { $0.id == selectedBookID }
            : placements
        let visibleIDs = Set(visible.map(\.id))
        for id in Array(markerEntities.keys) where !visibleIDs.contains(id) {
            markerEntities[id]?.removeFromParent()
            markerEntities.removeValue(forKey: id)
        }

        for placement in visible {
            let entity: ModelEntity
            if let existing = markerEntities[placement.id] {
                entity = existing
            } else {
                let mesh = MeshResource.generateSphere(radius: 0.028)
                var material = SimpleMaterial()
                material.color = .init(tint: .orange, texture: nil)
                entity = ModelEntity(mesh: mesh, materials: [material])
                markerEntities[placement.id] = entity
                markerAnchor.addChild(entity)
            }
            entity.position = SIMD3(placement.x, placement.y, placement.z)
        }
    }

    @objc private func handleTap(_ recognizer: UITapGestureRecognizer) {
        guard mode == .place, let selectedBookID, let originAnchor else { return }
        let point = recognizer.location(in: arView)
        guard let hit = arView.session.currentFrame?.hitTest(
            point,
            types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane, .featurePoint]
        ).first else {
            publish(.limited, message: "Aim at the shelf until a surface is detected.")
            return
        }
        let world = hit.worldTransform.columns.3
        let local = simd_mul(
            simd_inverse(originAnchor.transform),
            SIMD4<Float>(world.x, world.y, world.z, 1)
        )
        placementHandler?(selectedBookID, Placement(x: local.x, y: local.y, z: local.z))
        publish(.placed, message: "Book position saved.")
    }

    var placementHandler: ((String, Placement) -> Void)?

    private var isCameraTrackingNormally: Bool {
        guard let state = arView.session.currentFrame?.camera.trackingState else { return false }
        if case .normal = state { return true }
        return false
    }

    private func publish(_ status: ARTrackingStatus.Status, message: String) {
        currentStatus = status
        statusHandler?(ARTrackingStatus(status: status, message: message))
    }

    private func trackingMessage(for reason: ARCamera.TrackingState.Reason) -> String {
        switch reason {
        case .excessiveMotion: return "Move the phone more slowly."
        case .insufficientFeatures: return "Point at textured, well-lit parts of the shelf."
        case .initializing: return "Keep the shelf in view while ARKit starts."
        case .relocalizing: return "Searching for the saved shelf map."
        @unknown default: return "Keep the shelf in view."
        }
    }

    private func mappingMessage(for status: ARFrame.WorldMappingStatus) -> String {
        switch status {
        case .notAvailable: return "Move across the shelf so ARKit can start mapping it."
        case .limited: return "Keep panning slowly across textured, well-lit parts of the shelf."
        case .extending: return "Building the shelf map. Keep the full bookcase level in view."
        case .mapped: return "Shelf map is ready."
        @unknown default: return "Keep scanning the shelf."
        }
    }
}

struct ShelfARView: UIViewRepresentable {
    let controller: ShelfARController

    func makeUIView(context: Context) -> ARView {
        controller.start()
        return controller.arView
    }

    func updateUIView(_ uiView: ARView, context: Context) {}

    static func dismantleUIView(_ uiView: ARView, coordinator: ()) {
        // The owning screen controls the controller's lifecycle.
    }
}
