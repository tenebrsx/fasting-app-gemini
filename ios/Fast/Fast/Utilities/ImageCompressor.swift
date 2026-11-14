import Foundation
import UIKit

enum ImageCompressor {
    static func compress(_ data: Data, maxDimension: CGFloat = 560, maxBytes: Int = 300_000) -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }

        let scale = min(1.0, maxDimension / max(size.width, size.height))
        let targetSize = CGSize(
            width: (size.width * scale).rounded(),
            height: (size.height * scale).rounded()
        )

        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let resized = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }

        for quality in [0.72, 0.60, 0.45, 0.30] {
            if let jpeg = resized.jpegData(compressionQuality: quality), jpeg.count < maxBytes {
                return jpeg
            }
        }
        return resized.jpegData(compressionQuality: 0.25)
    }
}
