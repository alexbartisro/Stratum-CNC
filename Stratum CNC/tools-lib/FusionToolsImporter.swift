//
//  FusionToolsImporter.swift
//  Stratum CNC
//
//  Imports Fusion 360 tool libraries (`.tools`) and converts them to `Tool`.
//

import Foundation
import Compression

enum FusionImportError: LocalizedError {
    case notAnArchive
    case toolsJSONMissing
    case unsupportedCompression(UInt16)
    case decompressionFailed
    case invalidJSON(String)

    var errorDescription: String? {
        switch self {
        case .notAnArchive:
            "The file is not a valid Fusion .tools archive."
        case .toolsJSONMissing:
            "The archive does not contain a tools.json file."
        case .unsupportedCompression(let method):
            "The archive uses an unsupported compression method (\(method))."
        case .decompressionFailed:
            "The archive could not be decompressed."
        case .invalidJSON(let detail):
            "The tool library could not be parsed: \(detail)"
        }
    }
}

struct FusionImportResult {
    var tools: [Tool]
    /// Fusion entries that have no equivalent in our tool types (holders, probes, taps…).
    var unsupportedCount: Int
}

enum FusionToolsImporter {

    /// Reads a `.tools` file (a zip archive holding `tools.json`) and converts its tools.
    static func importTools(from url: URL) throws -> FusionImportResult {
        let fileData = try Data(contentsOf: url)
        let json: Data
        if fileData.starts(with: [0x50, 0x4B]) {            // "PK" — zip archive
            json = try ZipReader.extract(named: "tools.json", from: fileData)
        } else {                                              // some exports are plain JSON
            json = fileData
        }
        return try convert(json: json)
    }

    static func convert(json: Data) throws -> FusionImportResult {
        let library: FusionLibrary
        do {
            library = try JSONDecoder().decode(FusionLibrary.self, from: json)
        } catch {
            throw FusionImportError.invalidJSON(error.localizedDescription)
        }

        var tools: [Tool] = []
        var unsupported = 0
        for entry in library.data {
            if let tool = convert(entry) {
                tools.append(tool)
            } else {
                unsupported += 1
            }
        }
        return FusionImportResult(tools: tools, unsupportedCount: unsupported)
    }

    // MARK: - Mapping

    private static func convert(_ f: FusionTool) -> Tool? {
        guard let g = f.geometry,
              let diameter = g.DC, diameter > 0,
              let type = mapType(f) else { return nil }

        // Our library is in millimetres; Fusion stores values in the tool's own unit.
        let scale = f.unit?.lowercased().hasPrefix("inch") == true ? 25.4 : 1.0
        func mm(_ value: Double?) -> Double? {
            guard let value, value > 0 else { return nil }
            return (value * scale * 1000).rounded() / 1000
        }

        let shank = mm(g.SFDM) ?? mm(diameter)!
        // `length` in our model is the cutting length (flute length).
        let length = mm(g.LCF) ?? mm(g.shoulderLength) ?? mm(g.OAL)

        let productID = (f.productID ?? "").trimmingCharacters(in: .whitespaces)
        var name = (f.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            name = productID.isEmpty ? f.type : productID
        } else if !productID.isEmpty && !name.hasPrefix(productID) {
            name = "\(productID) \(name)"
        }

        let vendor = (f.vendor ?? "").trimmingCharacters(in: .whitespaces)
        let typeTitle = f.type.capitalized
        let group = vendor.isEmpty ? typeTitle : "\(vendor) \(typeTitle)"

        let link = f.productLink?.trimmingCharacters(in: .whitespaces)

        return Tool(
            id: UUID(uuidString: f.guid) ?? UUID(),
            name: name,
            shankDiameter: shank,
            toolDiameter: mm(diameter)!,
            length: length,
            type: type,
            group: group,
            quantity: 0,
            link: (link?.isEmpty ?? true) ? nil : link,
            tipAngle: tipAngle(for: type, geometry: g),
            parameters: parameters(from: f, scale: scale)
        )
    }

    /// Key used for the preset, since Fusion presets don't say which material they're for.
    static let noMaterialKey = "-"

    /// Fusion's first preset becomes a single entry under `noMaterialKey`.
    /// Feeds are stored in the tool's unit per minute, so they're scaled like lengths.
    private static func parameters(from f: FusionTool, scale: Double) -> [String: ToolCuttingParameters] {
        guard let preset = f.startValues?.presets?.first else { return [:] }

        func feed(_ value: Double?) -> Double? {
            guard let value, value > 0 else { return nil }
            return (value * scale * 10).rounded() / 10
        }

        let rpm = preset.n.flatMap { $0 > 0 ? Int($0.rounded()) : nil }
        let parameters = ToolCuttingParameters(
            spindleRPM: rpm,
            feedRate: feed(preset.vF),
            plungeFeedRate: feed(preset.vFPlunge),
            depthOfCut: nil             // Fusion presets here have no step-down
        )
        guard parameters.spindleRPM != nil || parameters.feedRate != nil else { return [:] }
        return [noMaterialKey: parameters]
    }

    private static func mapType(_ f: FusionTool) -> ToolType? {
        switch f.type.lowercased() {
        case "flat end mill", "bull nose end mill", "radius mill", "slot mill", "face mill":
            return .endMill
        case "ball end mill":
            return .ballNose
        case "tapered mill":
            return f.taperedType == "tapered_ball" ? .ballNose : .endMill
        case "chamfer mill":
            let text = (f.description ?? "").lowercased()
            return text.contains("engrav") ? .engraving : .chamfer
        case "counter sink":
            return .vBit
        case "drill", "center drill":
            return .drill
        default:
            return nil          // holder, probe, tap, thread mill, …
        }
    }

    /// Full included angle in degrees, where it applies.
    private static func tipAngle(for type: ToolType, geometry g: FusionGeometry) -> Double? {
        switch type {
        case .chamfer, .engraving:
            guard let ta = g.TA, ta > 0 else { return nil }
            return ta * 2                       // Fusion stores the half angle
        case .vBit, .drill:
            if let sig = g.SIG, sig > 0 { return sig }
            if let ta = g.TA, ta > 0 { return ta * 2 }
            return nil
        default:
            return nil
        }
    }
}

// MARK: - Fusion JSON

private struct FusionLibrary: Decodable {
    let data: [FusionTool]
}

private struct FusionTool: Decodable {
    let guid: String
    let description: String?
    let productID: String?
    let productLink: String?
    let type: String
    let unit: String?
    let vendor: String?
    let taperedType: String?
    let geometry: FusionGeometry?
    let startValues: FusionStartValues?

    enum CodingKeys: String, CodingKey {
        case guid, description, type, unit, vendor, geometry
        case startValues = "start-values"
        case productID = "product-id"
        case productLink = "product-link"
        case taperedType = "tapered-type"
    }
}

private struct FusionStartValues: Decodable {
    let presets: [FusionPreset]?
}

private struct FusionPreset: Decodable {
    let n: Double?                  // spindle speed, RPM
    let vF: Double?                 // cutting feed per minute
    let vFPlunge: Double?           // plunge feed per minute

    enum CodingKeys: String, CodingKey {
        case n
        case vF = "v_f"
        case vFPlunge = "v_f_plunge"
    }
}

private struct FusionGeometry: Decodable {
    let DC: Double?                 // cutting diameter
    let SFDM: Double?               // shank diameter
    let OAL: Double?                // overall length
    let LCF: Double?                // length of cutting flutes
    let TA: Double?                 // taper half angle
    let SIG: Double?                // point / tip angle
    let shoulderLength: Double?

    enum CodingKeys: String, CodingKey {
        case DC, SFDM, OAL, LCF, TA, SIG
        case shoulderLength = "shoulder-length"
    }
}

// MARK: - Minimal zip reader

/// Just enough of the zip format (stored + deflate) to read a `.tools` archive,
/// so we don't need a third-party dependency or to launch `/usr/bin/unzip`
/// (which the app sandbox would not allow).
private enum ZipReader {

    static func extract(named wanted: String, from data: Data) throws -> Data {
        let b = [UInt8](data)

        func u16(_ o: Int) -> Int { Int(b[o]) | Int(b[o + 1]) << 8 }
        func u32(_ o: Int) -> Int { u16(o) | u16(o + 2) << 16 }

        // End of central directory record, searched from the end of the file.
        guard b.count >= 22 else { throw FusionImportError.notAnArchive }
        var eocd = -1
        var i = b.count - 22
        while i >= max(0, b.count - 22 - 65_535) {
            if u32(i) == 0x0605_4B50 { eocd = i; break }
            i -= 1
        }
        guard eocd >= 0 else { throw FusionImportError.notAnArchive }

        let entryCount = u16(eocd + 10)
        var offset = u32(eocd + 16)

        for _ in 0..<entryCount {
            guard offset + 46 <= b.count, u32(offset) == 0x0201_4B50 else {
                throw FusionImportError.notAnArchive
            }
            let method = UInt16(u16(offset + 10))
            let compressedSize = u32(offset + 20)
            let nameLength = u16(offset + 28)
            let extraLength = u16(offset + 30)
            let commentLength = u16(offset + 32)
            let localOffset = u32(offset + 42)
            let nameBytes = b[(offset + 46)..<(offset + 46 + nameLength)]
            let name = String(decoding: nameBytes, as: UTF8.self)
            offset += 46 + nameLength + extraLength + commentLength

            guard (name as NSString).lastPathComponent.lowercased() == wanted else { continue }

            guard localOffset + 30 <= b.count, u32(localOffset) == 0x0403_4B50 else {
                throw FusionImportError.notAnArchive
            }
            let start = localOffset + 30 + u16(localOffset + 26) + u16(localOffset + 28)
            guard start + compressedSize <= b.count else { throw FusionImportError.notAnArchive }
            let payload = Data(b[start..<(start + compressedSize)])

            switch method {
            case 0:
                return payload
            case 8:
                do {
                    // Apple's .zlib algorithm is raw deflate, which is what zip stores.
                    return try (payload as NSData).decompressed(using: .zlib) as Data
                } catch {
                    throw FusionImportError.decompressionFailed
                }
            default:
                throw FusionImportError.unsupportedCompression(method)
            }
        }
        throw FusionImportError.toolsJSONMissing
    }
}
