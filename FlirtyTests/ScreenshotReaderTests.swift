import Testing
import UIKit
@testable import Flirty

@Suite("ScreenshotReader Tests")
struct ScreenshotReaderTests {

    /// Renders a fake chat bubble and checks Vision reads it back. Runs on the simulator.
    @Test("Extracts text from a rendered chat screenshot")
    func extractsText() async throws {
        let lines = ["hey, what are you up to tonight?", "nothing much, you?"]
        let size = CGSize(width: 600, height: 240)
        let image = UIGraphicsImageRenderer(size: size).image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 32),
                .foregroundColor: UIColor.black,
            ]
            for (i, line) in lines.enumerated() {
                line.draw(at: CGPoint(x: 24, y: 40 + CGFloat(i) * 80), withAttributes: attributes)
            }
        }
        let data = try #require(image.pngData())

        let text = try await ScreenshotReader.text(in: data)

        #expect(text.lowercased().contains("tonight"))
        #expect(text.lowercased().contains("nothing much"))
        #expect(text.split(separator: "\n").count == 2)
    }
}
