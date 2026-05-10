import AppKit
import Foundation
import UniformTypeIdentifiers

enum AppMetadataReaderError: Error, Equatable {
    case missingBundleIdentifier
    case notApplicationBundle
}

struct AppMetadataReader {
    func target(for url: URL) throws -> AppTarget {
        let contentType = try url.resourceValues(forKeys: [.contentTypeKey]).contentType
        guard url.pathExtension == "app" || contentType == .applicationBundle else {
            throw AppMetadataReaderError.notApplicationBundle
        }

        guard let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier,
              !bundleIdentifier.isEmpty
        else {
            throw AppMetadataReaderError.missingBundleIdentifier
        }

        let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent

        return AppTarget(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            path: url.path
        )
    }

    func icon(for target: AppTarget) -> NSImage {
        if let path = target.path {
            return NSWorkspace.shared.icon(forFile: path)
        }

        return NSWorkspace.shared.icon(for: .application)
    }
}
