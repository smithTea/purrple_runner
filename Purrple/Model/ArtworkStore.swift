import CoreImage
import SwiftUI
import UIKit

/// Cover art extracted from file tags, stored as downscaled JPEGs in
/// Application Support/Purrple/Artwork/<track id>.jpg.
final class ArtworkStore {
    static let shared = ArtworkStore()

    let directory: URL
    private let images = NSCache<NSString, UIImage>()
    private let colors = NSCache<NSString, UIColor>()
    private let ciContext = CIContext(options: [.workingColorSpace: NSNull()])

    private init() {
        directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Purrple/Artwork", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        images.countLimit = 200
    }

    static func fileURL(for id: UUID, in directory: URL) -> URL {
        directory.appendingPathComponent("\(id.uuidString).jpg")
    }

    /// Downscales and writes the image; returns false if the data isn't an image.
    static func saveArtwork(_ data: Data, for id: UUID, in directory: URL) -> Bool {
        guard let image = UIImage(data: data) else { return false }
        let maxSide: CGFloat = 600
        let scale = min(1, maxSide / max(image.size.width, image.size.height))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = image.preparingThumbnail(of: size) ?? image
        guard let jpeg = resized.jpegData(compressionQuality: 0.85) else { return false }
        return (try? jpeg.write(to: fileURL(for: id, in: directory), options: .atomic)) != nil
    }

    func image(for track: Track) -> UIImage? {
        guard track.hasArtwork else { return nil }
        let key = track.id.uuidString as NSString
        if let cached = images.object(forKey: key) { return cached }
        guard let image = UIImage(contentsOfFile: Self.fileURL(for: track.id, in: directory).path) else { return nil }
        images.setObject(image, forKey: key)
        return image
    }

    func remove(_ track: Track) {
        images.removeObject(forKey: track.id.uuidString as NSString)
        colors.removeObject(forKey: track.id.uuidString as NSString)
        try? FileManager.default.removeItem(at: Self.fileURL(for: track.id, in: directory))
    }

    /// Average artwork color, darkened so white text stays readable on it.
    func backgroundColor(for track: Track?) -> Color {
        guard let track else { return Theme.accentDark }
        let key = track.id.uuidString as NSString
        if let cached = colors.object(forKey: key) { return Color(cached) }
        guard let image = image(for: track), let average = averageColor(of: image) else { return Theme.accentDark }

        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        average.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        let tuned = UIColor(hue: h, saturation: min(1, s * 1.1), brightness: min(b, 0.45), alpha: 1)
        colors.setObject(tuned, forKey: key)
        return Color(tuned)
    }

    private func averageColor(of image: UIImage) -> UIColor? {
        guard let input = CIImage(image: image),
              let filter = CIFilter(name: "CIAreaAverage", parameters: [
                  kCIInputImageKey: input,
                  kCIInputExtentKey: CIVector(cgRect: input.extent),
              ]),
              let output = filter.outputImage
        else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        ciContext.render(output, toBitmap: &pixel, rowBytes: 4,
                         bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        return UIColor(red: CGFloat(pixel[0]) / 255, green: CGFloat(pixel[1]) / 255,
                       blue: CGFloat(pixel[2]) / 255, alpha: 1)
    }
}
