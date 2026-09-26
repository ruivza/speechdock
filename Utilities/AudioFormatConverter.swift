import Foundation

struct NormalizedAudioFormat {
    let mimeType: String
    let fileExtension: String
}

enum AudioFormatConverter {
    static func normalizeFormat(_ data: Data, originalExtension: String? = nil) -> NormalizedAudioFormat {
        let bytes = [UInt8](data.prefix(12))

        // WAV: RIFF header
        if bytes.starts(with: [0x52, 0x49, 0x46, 0x46]) {
            return NormalizedAudioFormat(mimeType: "audio/wav", fileExtension: "wav")
        }

        if bytes.starts(with: Array("fLaC".utf8)) {
            return NormalizedAudioFormat(mimeType: "audio/flac", fileExtension: "flac")
        }
        if bytes.count >= 12, bytes.starts(with: Array("FORM".utf8)),
           ["AIFF", "AIFC"].contains(String(bytes: bytes[8..<12], encoding: .ascii) ?? "") {
            return NormalizedAudioFormat(mimeType: "audio/aiff", fileExtension: "aiff")
        }
        // ADTS sync word, with MPEG layer bits required to be zero.
        if bytes.count >= 2, bytes[0] == 0xff, bytes[1] & 0xf6 == 0xf0 {
            return NormalizedAudioFormat(mimeType: "audio/aac", fileExtension: "aac")
        }

        // MP3: ID3 tag or MPEG sync word (MPEG-1/2/2.5, Layer II/III)
        if bytes.starts(with: [0x49, 0x44, 0x33]) ||
           bytes.starts(with: [0xFF, 0xFB]) ||
           bytes.starts(with: [0xFF, 0xFA]) ||
           bytes.starts(with: [0xFF, 0xF3]) ||
           bytes.starts(with: [0xFF, 0xF2]) ||
           bytes.starts(with: [0xFF, 0xE3]) ||
           bytes.starts(with: [0xFF, 0xE2]) {
            return NormalizedAudioFormat(mimeType: "audio/mpeg", fileExtension: "mp3")
        }

        // M4A/MP4: ftyp box
        if data.count > 8 {
            let ftypRange = data[4..<8]
            if String(data: ftypRange, encoding: .ascii) == "ftyp" {
                return NormalizedAudioFormat(mimeType: "audio/mp4", fileExtension: "m4a")
            }
        }

        // WebM: EBML header
        if bytes.starts(with: [0x1A, 0x45, 0xDF, 0xA3]) {
            return NormalizedAudioFormat(mimeType: "audio/webm", fileExtension: "webm")
        }

        // OGG: OggS header
        if bytes.starts(with: [0x4F, 0x67, 0x67, 0x53]) {
            return NormalizedAudioFormat(mimeType: "audio/ogg", fileExtension: "ogg")
        }

        // Fallback based on extension
        if let ext = originalExtension?.lowercased() {
            switch ext {
            case "flac": return NormalizedAudioFormat(mimeType: "audio/flac", fileExtension: "flac")
            case "aac": return NormalizedAudioFormat(mimeType: "audio/aac", fileExtension: "aac")
            case "aif", "aiff", "aifc": return NormalizedAudioFormat(mimeType: "audio/aiff", fileExtension: "aiff")
            case "wav": return NormalizedAudioFormat(mimeType: "audio/wav", fileExtension: "wav")
            case "ogg": return NormalizedAudioFormat(mimeType: "audio/ogg", fileExtension: "ogg")
            case "webm": return NormalizedAudioFormat(mimeType: "audio/webm", fileExtension: "webm")
            case "mp3", "mpeg":
                return NormalizedAudioFormat(mimeType: "audio/mpeg", fileExtension: "mp3")
            case "wave", "x-wav":
                return NormalizedAudioFormat(mimeType: "audio/wav", fileExtension: "wav")
            case "mp4a-latm":
                return NormalizedAudioFormat(mimeType: "audio/mp4", fileExtension: "m4a")
            default:
                break
            }
        }

        // Default to M4A (our recording format)
        return NormalizedAudioFormat(mimeType: "audio/mp4", fileExtension: "m4a")
    }

    static func mimeTypeForGemini(from format: NormalizedAudioFormat) -> String {
        switch format.fileExtension {
        case "mp3", "mpeg":
            return "audio/mp3"
        case "wav", "wave":
            return "audio/wav"
        case "m4a", "mp4":
            return "audio/mp4"
        case "aac": return "audio/aac"
        case "aiff": return "audio/aiff"
        case "webm": return "audio/webm"
        case "ogg":
            return "audio/ogg"
        case "flac":
            return "audio/flac"
        default:
            return "audio/mp3"
        }
    }
}
