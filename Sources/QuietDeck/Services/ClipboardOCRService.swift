import AppKit
import Vision

final class ClipboardOCRService {
    func recognizeText(in image: NSImage) async -> String? {
        var proposedRect = CGRect(origin: .zero, size: image.size)
        guard let cgImage = image.cgImage(forProposedRect: &proposedRect, context: nil, hints: nil) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = true
                let handler = VNImageRequestHandler(cgImage: cgImage)
                do {
                    try handler.perform([request])
                    let text = (request.results ?? [])
                        .compactMap { $0.topCandidates(1).first?.string }
                        .joined(separator: "\n")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: text.isEmpty ? nil : text)
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
