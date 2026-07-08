import Foundation
import os

final class ConfigStore {
    static let shared = ConfigStore()

    private let logger = Logger(subsystem: "com.freezy.MouseGestures", category: "ConfigStore")
    private let fileManager: FileManager
    private let configURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        let appSupport = try? fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = (appSupport ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support", isDirectory: true))
            .appendingPathComponent("MouseGestures", isDirectory: true)
        self.configURL = directory.appendingPathComponent("config.json")
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
    }

    var configFileURL: URL {
        return configURL
    }

    func load() -> Configuration {
        guard fileManager.fileExists(atPath: configURL.path) else {
            logger.info("No config file at \(self.configURL.path, privacy: .public); using defaults")
            return Configuration()
        }
        do {
            let attributes = try fileManager.attributesOfItem(atPath: configURL.path)
            if let size = attributes[.size] as? Int, size > Configuration.maxFileSize {
                logger.error("Config file too large (\(size) bytes); using defaults")
                return Configuration()
            }
            if let owner = attributes[.ownerAccountName] as? String {
                let current = NSUserName()
                if owner != current {
                    logger.error("Config file owned by \(owner, privacy: .public), expected \(current, privacy: .public); using defaults")
                    return Configuration()
                }
            }
            let data = try Data(contentsOf: configURL)
            let configuration = try decoder.decode(Configuration.self, from: data)
            return configuration
        } catch {
            logger.error("Failed to load config: \(error.localizedDescription, privacy: .public)")
            return Configuration()
        }
    }

    func save(_ configuration: Configuration) throws {
        let directory = configURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            try fileManager.setAttributes(
                [.posixPermissions: 0o700],
                ofItemAtPath: directory.path
            )
        }
        let data = try encoder.encode(configuration)
        let tempURL = configURL.appendingPathExtension("tmp")
        try data.write(to: tempURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: tempURL.path
        )
        if fileManager.fileExists(atPath: configURL.path) {
            _ = try fileManager.replaceItemAt(configURL, withItemAt: tempURL)
        } else {
            try fileManager.moveItem(at: tempURL, to: configURL)
        }
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: configURL.path
        )
    }
}
