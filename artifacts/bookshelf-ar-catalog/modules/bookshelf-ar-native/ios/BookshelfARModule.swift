import ARKit
import ExpoModulesCore
import RealityKit
import UIKit

private enum BookshelfARPersistence {
  private static let directoryName = "BookshelfAR"

  private static func mapURL(for shelfId: String) -> URL {
    let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    let safeId = shelfId.unicodeScalars.map {
      CharacterSet.alphanumerics.contains($0) ? String($0) : "_"
    }.joined()
    return base
      .appendingPathComponent(directoryName)
      .appendingPathComponent("shelf-\(safeId).arexperience")
  }

  static func loadMap(for shelfId: String) throws -> ARWorldMap {
    let data = try Data(contentsOf: mapURL(for: shelfId))
    guard let map = try NSKeyedUnarchiver.unarchivedObject(ofClass: ARWorldMap.self, from: data) else {
      throw NSError(domain: "BookshelfAR", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "The saved shelf map could not be decoded."
      ])
    }
    return map
  }

  static func saveMap(_ map: ARWorldMap, for shelfId: String) throws {
    let url = mapURL(for: shelfId)
    let directory = url.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: false)
    try data.write(to: url, options: .atomic)
  }

  static func clearMap(for shelfId: String) throws {
    let url = mapURL(for: shelfId)
    guard FileManager.default.fileExists(atPath: url.path) else { return }
    try FileManager.default.removeItem(at: url)
  }
}

private enum BookshelfARDevice {
  static var supportsTargetDevice: Bool {
    guard UIDevice.current.userInterfaceIdiom == .phone else { return false }
    #if targetEnvironment(simulator)
    return false
    #else
    var systemInfo = utsname()
    uname(&systemInfo)
    let identifier = withUnsafePointer(to: &systemInfo.machine) {
      $0.withMemoryRebound(to: CChar.self, capacity: 1) {
        String(cString: $0)
      }
    }
    guard identifier.hasPrefix("iPhone"),
          let generation = Int(identifier.dropFirst("iPhone".count).split(separator: ",").first ?? "") else {
      return false
    }
    // iPhone13,* is the iPhone 12 family; higher identifiers are newer iPhones.
    return generation >= 13
    #endif
  }
}

private struct PlacementRecord: Decodable {
  let id: String
  let x: Float
  let y: Float
  let z: Float
}

final class BookshelfARView: ExpoView, ARSessionDelegate {
  static weak var activeView: BookshelfARView?

  private let arView = RealityKit.ARView(frame: .zero)
  private let markerAnchor = AnchorEntity(world: .zero)
  private var originAnchor: ARAnchor?
  private var started = false
  private var currentStatus: String = "unavailable"
  private var markerEntities: [String: ModelEntity] = [:]
  private var relocalizationWorkItem: DispatchWorkItem?
  private var originSaveTimeout: DispatchWorkItem?
  private var pendingOriginSave: (promise: Promise, shelfId: String)?
  private var pendingOriginAnchor: ARAnchor?
  private var activeOriginSaveAnchorId: UUID?
  private var isWorldMapReady = false

  var mode: String = "scan" {
    didSet {
      guard oldValue != mode, window != nil else { return }
      updateMarkers()
      startSession()
    }
  }

  var shelfId: String = "shelf-default" {
    didSet {
      guard oldValue != shelfId else { return }
      originAnchor = nil
      markerAnchor.transform = Transform()
      updateMarkers()
      guard window != nil else { return }
      startSession()
    }
  }

  var selectedBookId: String? {
    didSet {
      guard oldValue != selectedBookId else { return }
      updateMarkers()
    }
  }
  var placementsJSON: String = "[]" {
    didSet {
      guard oldValue != placementsJSON else { return }
      updateMarkers()
    }
  }

  required init(appContext: AppContext? = nil) {
    super.init(appContext: appContext)
    backgroundColor = .black
    arView.session.delegate = self
    arView.automaticallyConfigureSession = false
    arView.scene.addAnchor(markerAnchor)
    addSubview(arView)
    arView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      arView.leadingAnchor.constraint(equalTo: leadingAnchor),
      arView.trailingAnchor.constraint(equalTo: trailingAnchor),
      arView.topAnchor.constraint(equalTo: topAnchor),
      arView.bottomAnchor.constraint(equalTo: bottomAnchor)
    ])

    let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
    arView.addGestureRecognizer(tap)
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard window != nil else { return }
    BookshelfARView.activeView = self
    if !started {
      startSession()
    }
  }

  override func removeFromSuperview() {
    if BookshelfARView.activeView === self {
      BookshelfARView.activeView = nil
    }
    relocalizationWorkItem?.cancel()
    originSaveTimeout?.cancel()
    if let pendingOriginAnchor {
      arView.session.remove(anchor: pendingOriginAnchor)
      self.pendingOriginAnchor = nil
    }
    if let pendingOriginSave {
      pendingOriginSave.promise.resolve(["saved": false, "reason": "ar-view-dismissed"])
      self.pendingOriginSave = nil
    }
    arView.session.pause()
    super.removeFromSuperview()
  }

  private func startSession() {
    guard BookshelfARDevice.supportsTargetDevice && ARWorldTrackingConfiguration.isSupported else {
      publishStatus("unavailable", message: "Shelf mapping requires an iPhone 12 or newer with ARKit world tracking.")
      return
    }

    let configuration = ARWorldTrackingConfiguration()
    configuration.planeDetection = [.horizontal, .vertical]
    configuration.environmentTexturing = .automatic
    let options: ARSession.RunOptions = [.resetTracking, .removeExistingAnchors]
    relocalizationWorkItem?.cancel()
    originSaveTimeout?.cancel()
    if let pendingOriginSave {
      pendingOriginSave.promise.resolve(["saved": false, "reason": "ar-session-restarted"])
      self.pendingOriginSave = nil
    }
    pendingOriginAnchor = nil
    activeOriginSaveAnchorId = nil
    isWorldMapReady = false
    originAnchor = nil
    markerAnchor.transform = Transform()

    if mode == "locate" || mode == "place" {
      do {
        configuration.initialWorldMap = try BookshelfARPersistence.loadMap(for: shelfId)
      } catch {
        started = false
        publishStatus("shelf_not_found", message: "This shelf has not been mapped on this device yet.")
        return
      }
    }

    started = true
    arView.session.run(configuration, options: options)
    publishStatus(
      mode == "scan" ? "scanning" : "searching",
      message: mode == "scan" ? "Move across the shelf until the map is ready to save." : nil
    )
    if mode == "locate" || mode == "place" {
      let timeout = DispatchWorkItem { [weak self] in
        guard let self, self.originAnchor == nil else { return }
        self.publishStatus("shelf_not_found", message: "The saved shelf could not be relocalized. Re-scan this shelf to continue.")
      }
      relocalizationWorkItem = timeout
      DispatchQueue.main.asyncAfter(deadline: .now() + 12, execute: timeout)
    }
  }

  func setShelfOrigin(_ promise: Promise, shelfId requestedShelfId: String) {
    guard BookshelfARDevice.supportsTargetDevice && ARWorldTrackingConfiguration.isSupported else {
      promise.resolve(["saved": false, "reason": "iphone-12-or-newer-required"])
      return
    }
    guard mode == "scan", isWorldMapReady, isCameraTrackingNormally else {
      promise.resolve(["saved": false, "reason": "tracking-not-ready"])
      return
    }
    guard requestedShelfId == shelfId else {
      promise.resolve(["saved": false, "reason": "shelf-view-mismatch"])
      return
    }
    guard pendingOriginSave == nil else {
      promise.resolve(["saved": false, "reason": "shelf-save-in-progress"])
      return
    }

    let center = CGPoint(x: arView.bounds.midX, y: arView.bounds.midY)
    let hit = arView.session.currentFrame?.hitTest(
      center,
      types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane, .featurePoint]
    ).first
    guard let hit else {
      promise.resolve(["saved": false, "reason": "shelf-surface-not-found"])
      publishStatus("limited", message: "Aim the center of the screen at the shelf until a surface is detected.")
      return
    }
    let anchor = ARAnchor(name: "bookshelf-origin", transform: hit.worldTransform)
    originAnchor = anchor
    pendingOriginAnchor = anchor
    pendingOriginSave = (promise, requestedShelfId)
    let timeout = DispatchWorkItem { [weak self] in
      guard let self,
            let pending = self.pendingOriginSave,
            self.pendingOriginAnchor?.identifier == anchor.identifier else { return }
      self.pendingOriginSave = nil
      self.pendingOriginAnchor = nil
      self.arView.session.remove(anchor: anchor)
      if self.originAnchor?.identifier == anchor.identifier {
        self.originAnchor = nil
        self.markerAnchor.transform = Transform()
      }
      pending.promise.resolve(["saved": false, "reason": "anchor-not-added"])
      self.publishStatus("limited", message: "ARKit could not save the shelf anchor. Keep the shelf in view and try again.")
    }
    originSaveTimeout = timeout
    DispatchQueue.main.asyncAfter(deadline: .now() + 4, execute: timeout)
    arView.session.add(anchor: anchor)
  }

  private func saveCurrentWorldMap(_ promise: Promise, shelfId: String, expectedAnchorId: UUID) {
    guard isCameraTrackingNormally,
          arView.session.currentFrame?.worldMappingStatus == .mapped else {
      rejectOriginSave(promise, anchorId: expectedAnchorId, reason: "tracking-degraded-before-save")
      return
    }
    activeOriginSaveAnchorId = expectedAnchorId
    arView.session.getCurrentWorldMap { worldMap, error in
      DispatchQueue.main.async {
        guard self.activeOriginSaveAnchorId == expectedAnchorId else { return }
        self.activeOriginSaveAnchorId = nil
        guard let worldMap else {
          self.rejectOriginSave(
            promise,
            anchorId: expectedAnchorId,
            reason: error?.localizedDescription ?? "world-map-unavailable"
          )
          return
        }
        guard self.isCameraTrackingNormally,
              self.arView.session.currentFrame?.worldMappingStatus == .mapped,
              worldMap.anchors.contains(where: { $0.identifier == expectedAnchorId }) else {
          self.rejectOriginSave(promise, anchorId: expectedAnchorId, reason: "world-map-not-ready")
          return
        }
        do {
          try BookshelfARPersistence.saveMap(worldMap, for: shelfId)
          promise.resolve([
            "saved": true,
            "mapId": UUID().uuidString,
            "savedAt": ISO8601DateFormatter().string(from: Date())
          ])
          self.publishStatus("shelf_found", message: "Shelf origin saved on this device.")
        } catch {
          promise.resolve(["saved": false, "reason": error.localizedDescription])
        }
      }
    }
  }

  private func rejectOriginSave(_ promise: Promise, anchorId: UUID, reason: String) {
    if let anchor = originAnchor, anchor.identifier == anchorId {
      arView.session.remove(anchor: anchor)
      originAnchor = nil
      markerAnchor.transform = Transform()
    }
    promise.resolve(["saved": false, "reason": reason])
    publishStatus("limited", message: "ARKit could not save a stable shelf map. Keep the shelf in view and try again.")
  }

  func clearWorldMap(_ promise: Promise, shelfId: String) {
    do {
      try BookshelfARPersistence.clearMap(for: shelfId)
      promise.resolve(["cleared": true])
    } catch {
      promise.resolve(["cleared": false])
    }
  }

  func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    switch camera.trackingState {
    case .normal:
      if mode == "scan" {
        publishStatus(
          isWorldMapReady ? "ready_to_place" : "scanning",
          message: isWorldMapReady
            ? "Shelf map is ready. Aim at the shelf and save the origin."
            : "Keep scanning until ARKit finishes building the shelf map."
        )
      } else if originAnchor != nil {
        publishStatus("shelf_found", message: "Shelf found. Keep the bookcase in view.")
      } else {
        publishStatus("searching")
      }
    case .limited(let reason):
      publishStatus("limited", message: trackingMessage(for: reason))
    case .notAvailable:
      publishStatus("unavailable", message: "ARKit tracking is not available right now.")
    }
  }

  func session(_ session: ARSession, didUpdate frame: ARFrame) {
    guard mode == "scan" else { return }
    let mapIsReady = frame.worldMappingStatus == .mapped
    guard mapIsReady != isWorldMapReady else { return }
    isWorldMapReady = mapIsReady

    if mapIsReady, isCameraTrackingNormally {
      publishStatus("ready_to_place", message: "Shelf map is ready. Aim at the shelf and save the origin.")
    } else {
      publishStatus("scanning", message: mappingMessage(for: frame.worldMappingStatus))
    }
  }

  func session(_ session: ARSession, didAdd anchors: [ARAnchor]) {
    for anchor in anchors where anchor.name == "bookshelf-origin" {
      guard mode != "scan" || pendingOriginAnchor?.identifier == anchor.identifier else {
        if mode == "scan" {
          session.remove(anchor: anchor)
        }
        continue
      }
      relocalizationWorkItem?.cancel()
      originAnchor = anchor
      markerAnchor.transform = Transform(matrix: anchor.transform)
      updateMarkers()
      if mode == "scan", let pendingOriginSave {
        self.pendingOriginSave = nil
        self.pendingOriginAnchor = nil
        originSaveTimeout?.cancel()
        saveCurrentWorldMap(
          pendingOriginSave.promise,
          shelfId: pendingOriginSave.shelfId,
          expectedAnchorId: anchor.identifier
        )
      }
      publishStatus(mode == "scan" ? "ready_to_place" : "shelf_found")
    }
  }

  func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
    for anchor in anchors where anchor.name == "bookshelf-origin" {
      originAnchor = anchor
      markerAnchor.transform = Transform(matrix: anchor.transform)
    }
  }

  private func trackingMessage(for reason: ARCamera.TrackingState.Reason) -> String {
    switch reason {
    case .excessiveMotion:
      return "Move the phone more slowly."
    case .insufficientFeatures:
      return "Point at textured, well-lit parts of the shelf."
    case .initializing:
      return "Keep the shelf in view while ARKit starts."
    case .relocalizing:
      return "Searching for the saved shelf map."
    @unknown default:
      return "Keep the shelf in view."
    }
  }

  private var isCameraTrackingNormally: Bool {
    guard let trackingState = arView.session.currentFrame?.camera.trackingState else { return false }
    if case .normal = trackingState {
      return true
    }
    return false
  }

  private func mappingMessage(for status: ARFrame.WorldMappingStatus) -> String {
    switch status {
    case .notAvailable:
      return "Move across the shelf so ARKit can start mapping it."
    case .limited:
      return "Keep panning slowly across textured, well-lit parts of the shelf."
    case .extending:
      return "Building the shelf map. Keep the full bookcase level in view."
    case .mapped:
      return "Shelf map is ready."
    @unknown default:
      return "Keep scanning the shelf."
    }
  }

  private func publishStatus(_ status: String, message: String? = nil) {
    guard status != currentStatus || message != nil else { return }
    currentStatus = status
    var payload: [String: Any] = ["status": status]
    if let message {
      payload["message"] = message
    }
    dispatchEvent("onTrackingStatusChanged", payload: payload)
  }

  private func updateMarkers() {
    guard let data = placementsJSON.data(using: .utf8),
          let placements = try? JSONDecoder().decode([PlacementRecord].self, from: data) else {
      return
    }

    let visiblePlacements = mode == "locate" && selectedBookId != nil
      ? placements.filter { $0.id == selectedBookId }
      : placements
    let ids = Set(visiblePlacements.map(\.id))
    let staleIds = markerEntities.keys.filter { !ids.contains($0) }
    for id in staleIds {
      markerEntities[id]?.removeFromParent()
      markerEntities.removeValue(forKey: id)
    }

    for placement in visiblePlacements {
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
    guard mode == "place", let selectedBookId, let originAnchor else { return }
    let point = recognizer.location(in: arView)
    let results = arView.session.currentFrame?.hitTest(
      point,
      types: [.existingPlaneUsingExtent, .estimatedHorizontalPlane, .featurePoint]
    ) ?? []
    guard let hit = results.first else {
      publishStatus("limited", message: "Aim at the shelf until a surface is detected.")
      return
    }

    let world = hit.worldTransform.columns.3
    let local = simd_mul(simd_inverse(originAnchor.transform), SIMD4<Float>(world.x, world.y, world.z, 1))
    dispatchEvent("onBookPlaced", payload: [
      "bookId": selectedBookId,
      "x": local.x,
      "y": local.y,
      "z": local.z
    ])
    publishStatus("placed", message: "Book position saved.")
  }
}

public final class BookshelfARModule: Module {
  public func definition() -> ModuleDefinition {
    Name("BookshelfAR")

    View(BookshelfARView.self) {
      Events("onTrackingStatusChanged", "onBookPlaced")

      Prop("mode") { (view: BookshelfARView, mode: String) in
        view.mode = mode
      }
      Prop("shelfId") { (view: BookshelfARView, shelfId: String) in
        view.shelfId = shelfId
      }
      Prop("selectedBookId") { (view: BookshelfARView, bookId: String?) in
        view.selectedBookId = bookId
      }
      Prop("placementsJSON") { (view: BookshelfARView, placements: String?) in
        view.placementsJSON = placements ?? "[]"
      }
    }

    AsyncFunction("setShelfOrigin") { (shelfId: String, promise: Promise) in
      guard let view = BookshelfARView.activeView else {
        promise.resolve(["saved": false, "reason": "ar-view-unavailable"])
        return
      }
      view.setShelfOrigin(promise, shelfId: shelfId)
    }

    AsyncFunction("clearWorldMap") { (shelfId: String, promise: Promise) in
      guard let view = BookshelfARView.activeView else {
        do {
          try BookshelfARPersistence.clearMap(for: shelfId)
          promise.resolve(["cleared": true])
        } catch {
          promise.resolve(["cleared": false])
        }
        return
      }
      view.clearWorldMap(promise, shelfId: shelfId)
    }
  }
}