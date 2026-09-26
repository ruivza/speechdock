import Foundation

/// Converts Gemini REST audio parts to one PCM WAV, shared by playback and export.
enum GeminiTTSAudio {
    private struct Format: Equatable {
        let rate: UInt32
        let channels: UInt16
        let bits: UInt16
        var alignment: UInt32 { UInt32(channels) * UInt32(bits / 8) }
    }

    static func makeWAV(from parts: [[String: Any]]) throws -> Data {
        var pcm = Data()
        var format: Format?
        for part in parts {
            guard let inline = part["inlineData"] as? [String: Any] else { continue }
            guard let encoded = inline["data"] as? String,
                  let data = Data(base64Encoded: encoded), !data.isEmpty else {
                throw invalid("Invalid audio part")
            }
            let decoded = try decode(data, mimeType: inline["mimeType"] as? String ?? "audio/l16;rate=24000")
            if let format, format != decoded.0 {
                throw invalid("Audio part formats differ (sample rate, channels or bit depth)")
            }
            format = decoded.0
            pcm.append(decoded.1)
        }
        guard let format, !pcm.isEmpty, pcm.count <= Int(UInt32.max) - 37 else {
            throw invalid("Missing or oversized audio data")
        }
        let padding = pcm.count % 2
        var wav = Data("RIFF".utf8)
        append(UInt32(36 + pcm.count + padding), to: &wav)
        wav.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16), to: &wav)
        append(UInt16(1), to: &wav)
        append(format.channels, to: &wav)
        append(format.rate, to: &wav)
        append(format.rate * format.alignment, to: &wav)
        append(UInt16(format.alignment), to: &wav)
        append(format.bits, to: &wav)
        wav.append(contentsOf: "data".utf8)
        append(UInt32(pcm.count), to: &wav)
        wav.append(pcm)
        if padding != 0 { wav.append(0) }
        return wav
    }

    private static func decode(_ data: Data, mimeType: String) throws -> (Format, Data) {
        let bytes = [UInt8](data)
        func value(_ offset: Int, _ size: Int) -> UInt32 {
            (0..<size).reduce(0) { $0 | UInt32(bytes[offset + $1]) << ($1 * 8) }
        }
        func tag(_ offset: Int, _ text: String) -> Bool {
            offset + 4 <= bytes.count && bytes[offset..<offset + 4].elementsEqual(text.utf8)
        }
        if tag(0, "RIFF") {
            guard bytes.count >= 12, tag(8, "WAVE"), Int(value(4, 4)) + 8 == bytes.count else {
                throw invalid("Truncated or invalid RIFF container")
            }
            var offset = 12
            var format: Format?
            var pcm = Data()
            while offset < bytes.count {
                guard offset + 8 <= bytes.count else { throw invalid("Truncated WAV chunk") }
                let size = Int(value(offset + 4, 4))
                let start = offset + 8
                guard size <= bytes.count - start else { throw invalid("Truncated WAV chunk payload") }
                if tag(offset, "fmt ") {
                    guard size >= 16, value(start, 2) == 1, format == nil else {
                        throw invalid("Only PCM WAV with one fmt chunk is supported")
                    }
                    let candidate = Format(rate: value(start + 4, 4), channels: UInt16(value(start + 2, 2)), bits: UInt16(value(start + 14, 2)))
                    try validate(candidate)
                    guard value(start + 12, 2) == candidate.alignment,
                          value(start + 8, 4) == candidate.rate * candidate.alignment else {
                        throw invalid("Inconsistent WAV format")
                    }
                    format = candidate
                } else if tag(offset, "data") {
                    pcm.append(contentsOf: bytes[start..<start + size])
                }
                offset = start + size + size % 2
                guard offset <= bytes.count else { throw invalid("Missing WAV chunk padding") }
            }
            guard let format, !pcm.isEmpty, pcm.count % Int(format.alignment) == 0 else {
                throw invalid("Missing WAV format/data or incomplete PCM frame")
            }
            return (format, pcm)
        }
        // Gemini's REST l16 payloads contain little-endian, mono Int16 PCM.
        // Container detection uses the bytes; MIME labels alone are not sufficient.
        let mime = mimeType.lowercased().replacingOccurrences(of: " ", with: "")
        let mediaType = mime.split(separator: ";").first.map(String.init) ?? ""
        guard ["audio/l16", "audio/pcm", "audio/wav", "audio/x-wav"].contains(mediaType) else {
            throw invalid("Unsupported audio MIME type")
        }
        let format = Format(rate: AudioConverter.extractSampleRate(from: mime), channels: 1, bits: 16)
        try validate(format)
        guard data.count % Int(format.alignment) == 0 else { throw invalid("Incomplete PCM frame") }
        return (format, data)
    }

    private static func validate(_ format: Format) throws {
        guard format.rate > 0, format.channels > 0, [8, 16, 24, 32].contains(format.bits),
              format.alignment <= UInt32(UInt16.max),
              UInt64(format.rate) * UInt64(format.alignment) <= UInt64(UInt32.max) else {
            throw invalid("Unsupported PCM format")
        }
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }

    private static func invalid(_ message: String) -> TTSError { .audioError(message) }
}
