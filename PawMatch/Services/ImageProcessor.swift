import UIKit

/// Client-side downscale + JPEG compression before upload (§10.3): target ~1080px
/// on the longest edge at ~70% quality to control Storage cost and load time.
enum ImageProcessor {
    static func compressedJPEG(
        from image: UIImage,
        maxDimension: CGFloat = 1080,
        quality: CGFloat = 0.7
    ) -> Data? {
        let resized = downscale(image, maxDimension: maxDimension)
        return resized.jpegData(compressionQuality: quality)
    }

    private static func downscale(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let longestEdge = max(image.size.width, image.size.height)
        guard longestEdge > maxDimension else { return image }

        let scale = maxDimension / longestEdge
        let newSize = CGSize(width: image.size.width * scale, height: image.size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
