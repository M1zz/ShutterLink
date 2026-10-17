import AVFoundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

struct Shot: Codable, Identifiable, Equatable {
    enum Kind: String, Codable {
        case photo
        case video
    }

    let id: UUID
    let date: Date
    let kind: Kind
    let fileName: String
    var burstID: UUID?
    var isBest = false
}

/// Keeps every shot from ShutterLink inside the app, so the camera owner can review a burst,
/// see which frame was picked as the best, and AirDrop photos to the group right away.
final class ShotStore: ObservableObject {
    @Published private(set) var shots: [Shot] = []

    private let ioQueue = DispatchQueue(label: "shutterlink.shots", qos: .utility)
    private let directory: URL
    private var indexURL: URL { directory.appendingPathComponent("index.json") }

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        directory = base.appendingPathComponent("Shots", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? Data(contentsOf: indexURL),
           let saved = try? JSONDecoder().decode([Shot].self, from: data) {
            shots = saved.filter { FileManager.default.fileExists(atPath: directory.appendingPathComponent($0.fileName).path) }
        }
    }

    func fileURL(for shot: Shot) -> URL {
        directory.appendingPathComponent(shot.fileName)
    }

    func thumbnailURL(for shot: Shot) -> URL {
        directory.appendingPathComponent("\(shot.id.uuidString)-thumb.jpg")
    }

    func shots(inBurst burstID: UUID) -> [Shot] {
        shots.filter { $0.burstID == burstID }
    }

    /// Writes the photo and its thumbnail; `completion` runs on main with the new shot.
    func addPhoto(_ data: Data, burstID: UUID?, completion: ((Shot) -> Void)? = nil) {
        let id = UUID()
        let ext = Self.fileExtension(for: data)
        let shot = Shot(id: id, date: Date(), kind: .photo, fileName: "\(id.uuidString).\(ext)", burstID: burstID)
        ioQueue.async {
            do {
                try data.write(to: self.fileURL(for: shot), options: .atomic)
            } catch {
                return
            }
            if let thumb = Self.thumbnail(fromImageData: data, maxPixel: 400) {
                try? thumb.write(to: self.thumbnailURL(for: shot), options: .atomic)
            }
            DispatchQueue.main.async {
                self.shots.insert(shot, at: 0)
                self.persist()
                completion?(shot)
            }
        }
    }

    /// Moves the recorded movie into the store.
    func addVideo(movingFrom url: URL) {
        let id = UUID()
        let shot = Shot(id: id, date: Date(), kind: .video, fileName: "\(id.uuidString).mov")
        ioQueue.async {
            do {
                try FileManager.default.moveItem(at: url, to: self.fileURL(for: shot))
            } catch {
                try? FileManager.default.removeItem(at: url)
                return
            }
            let generator = AVAssetImageGenerator(asset: AVURLAsset(url: self.fileURL(for: shot)))
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 400, height: 400)
            if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil),
               let jpeg = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.7) {
                try? jpeg.write(to: self.thumbnailURL(for: shot), options: .atomic)
            }
            DispatchQueue.main.async {
                self.shots.insert(shot, at: 0)
                self.persist()
            }
        }
    }

    func markBest(_ id: UUID, inBurst burstID: UUID) {
        for index in shots.indices where shots[index].burstID == burstID {
            shots[index].isBest = shots[index].id == id
        }
        persist()
    }

    func delete(_ ids: Set<UUID>) {
        let removed = shots.filter { ids.contains($0.id) }
        shots.removeAll { ids.contains($0.id) }
        persist()
        ioQueue.async {
            for shot in removed {
                try? FileManager.default.removeItem(at: self.fileURL(for: shot))
                try? FileManager.default.removeItem(at: self.thumbnailURL(for: shot))
            }
        }
    }

    func deleteAll() {
        delete(Set(shots.map(\.id)))
    }

    private func persist() {
        let snapshot = shots
        ioQueue.async {
            if let data = try? JSONEncoder().encode(snapshot) {
                try? data.write(to: self.indexURL, options: .atomic)
            }
        }
    }

    // MARK: Helpers

    static func thumbnail(fromImageData data: Data, maxPixel: Int, quality: CGFloat = 0.7) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                  kCGImageSourceCreateThumbnailFromImageAlways: true,
                  kCGImageSourceCreateThumbnailWithTransform: true,
                  kCGImageSourceThumbnailMaxPixelSize: maxPixel
              ] as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage).jpegData(compressionQuality: quality)
    }

    private static func fileExtension(for data: Data) -> String {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let typeID = CGImageSourceGetType(source) as String?,
              let type = UTType(typeID) else { return "jpg" }
        return type.preferredFilenameExtension ?? "jpg"
    }
}
