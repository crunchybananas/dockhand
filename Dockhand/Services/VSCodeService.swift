//
//  VSCodeService.swift
//  Dockhand
//
//  Created by Cory Loken on 2/5/26.
//
//  Writes / updates VS Code MCP config so the editor can talk to Dockhand's
//  MCP server without manual JSON editing.
//

import Foundation

final class VSCodeService: Sendable {
  static let shared = VSCodeService()
  private init() {}

  // MARK: - Types

  enum ConfigTarget: Sendable {
    case user
    case workspace(path: String)
  }

  enum VSCodeError: LocalizedError {
    case noConfigDir
    case readFailed(String)
    case writeFailed(String)

    var errorDescription: String? {
      switch self {
      case .noConfigDir: return "Could not locate VS Code config directory"
      case .readFailed(let msg): return "Failed to read settings: \(msg)"
      case .writeFailed(let msg): return "Failed to write settings: \(msg)"
      }
    }
  }

  // MARK: - Public API

  /// Installs (or updates) an MCP server entry in VS Code's `mcp.json`.
  /// Returns the path that was written.
  func installMCPConfig(
    serverName: String,
    serverURL: String,
    scope: ConfigTarget
  ) throws -> String {
    let configURL = try mcpConfigURL(for: scope)
    let configDir = configURL.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)

    var config = try readSettings(from: configURL)
    var servers = config["servers"] as? [String: Any] ?? [:]
    servers[serverName] = [
      "type": "http",
      "url": serverURL
    ]
    config["servers"] = servers
    if config["inputs"] == nil {
      config["inputs"] = [Any]()
    }

    try writeSettings(config, to: configURL)
    return configURL.path
  }

  // MARK: - Private

  private func mcpConfigURL(for scope: ConfigTarget) throws -> URL {
    switch scope {
    case .user:
      guard let appSupport = FileManager.default.urls(
        for: .applicationSupportDirectory, in: .userDomainMask
      ).first else {
        throw VSCodeError.noConfigDir
      }
      return appSupport
        .appendingPathComponent("Code")
        .appendingPathComponent("User")
        .appendingPathComponent("mcp.json")

    case .workspace(let path):
      return URL(fileURLWithPath: path)
        .appendingPathComponent(".vscode")
        .appendingPathComponent("mcp.json")
    }
  }

  private func readSettings(from url: URL) throws -> [String: Any] {
    guard FileManager.default.fileExists(atPath: url.path) else {
      return [:]
    }
    do {
      let data = try Data(contentsOf: url)
      guard let dict = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
        return [:]
      }
      return dict
    } catch {
      throw VSCodeError.readFailed(error.localizedDescription)
    }
  }

  private func writeSettings(_ dict: [String: Any], to url: URL) throws {
    do {
      let data = try JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted, .sortedKeys])
      try data.write(to: url, options: .atomic)
    } catch {
      throw VSCodeError.writeFailed(error.localizedDescription)
    }
  }
}
