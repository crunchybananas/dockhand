//
//  ShipGenerator.swift
//  Dockhand
//
//  Created by Cory Loken on 2/2/26.
//
//  Autonomous ship (microtool) generation using LLM
//

import Foundation

/// Handles autonomous creation of new microtools/ships
@MainActor
final class ShipGenerator {
  private let llmService: LLMService
  private let microtoolsPath: String
  
  /// Path to the microtools repository
  nonisolated static let defaultMicrotoolsPath = "/Users/cloken/code/Dockhand/shipyard-microtools/docs"
  
  init(llmService: LLMService, microtoolsPath: String = defaultMicrotoolsPath) {
    self.llmService = llmService
    self.microtoolsPath = microtoolsPath
  }
  
  // MARK: - Public API
  
  /// Generate a new ship idea, create the code, and optionally submit
  func generateShip(submit: Bool = false, apiKey: String?) async throws -> GeneratedShip? {
    // 1. Get existing tools to avoid duplicates
    let existingTools = getExistingTools()
    
    // 2. Generate a new idea
    guard let idea = try await llmService.generateShipIdea(existingShips: existingTools) else {
      throw ShipGeneratorError.ideaGenerationFailed
    }
    
    // 3. Generate the code
    guard let code = try await llmService.generateMicrotoolCode(idea: idea) else {
      throw ShipGeneratorError.codeGenerationFailed
    }
    
    // 4. Write files to disk
    let toolPath = try writeToolFiles(idea: idea, code: code)
    
    // 5. Update index.html
    try updateIndexFile(idea: idea)
    
    // 6. Git commit and push
    try await gitCommitAndPush(idea: idea)
    
    // 7. Construct the proof URL
    let proofUrl = "https://crunchybananas.github.io/shipyard-microtools/\(idea.slug)/"
    
    // 8. Submit to Shipyard if requested
    var shipId: String?
    if submit, let apiKey {
      shipId = try await submitToShipyard(idea: idea, proofUrl: proofUrl, apiKey: apiKey)
    }
    
    return GeneratedShip(
      idea: idea,
      code: code,
      localPath: toolPath,
      proofUrl: proofUrl,
      shipId: shipId
    )
  }
  
  /// Get list of existing tool names
  func getExistingTools() -> [String] {
    let fileManager = FileManager.default
    guard let contents = try? fileManager.contentsOfDirectory(atPath: microtoolsPath) else {
      return []
    }
    
    return contents.filter { name in
      var isDir: ObjCBool = false
      let path = "\(microtoolsPath)/\(name)"
      return fileManager.fileExists(atPath: path, isDirectory: &isDir) && isDir.boolValue && !name.hasPrefix(".")
    }
  }
  
  // MARK: - Private Methods
  
  private func writeToolFiles(idea: ShipIdea, code: MicrotoolCode) throws -> String {
    let toolPath = "\(microtoolsPath)/\(idea.slug)"
    let fileManager = FileManager.default
    
    // Create directory
    try fileManager.createDirectory(atPath: toolPath, withIntermediateDirectories: true)
    
    // Write HTML
    let htmlPath = "\(toolPath)/index.html"
    try code.html.write(toFile: htmlPath, atomically: true, encoding: .utf8)
    
    // Write CSS if separate
    if !code.css.isEmpty {
      let cssPath = "\(toolPath)/styles.css"
      try code.css.write(toFile: cssPath, atomically: true, encoding: .utf8)
    }
    
    // Write JS if separate
    if !code.js.isEmpty {
      let jsPath = "\(toolPath)/app.js"
      try code.js.write(toFile: jsPath, atomically: true, encoding: .utf8)
    }
    
    return toolPath
  }
  
  private func updateIndexFile(idea: ShipIdea) throws {
    let indexPath = "\(microtoolsPath)/index.html"
    guard var indexContent = try? String(contentsOfFile: indexPath, encoding: .utf8) else {
      return
    }
    
    // Find the tools grid and add the new tool
    let newToolEntry = """
            <a href="\(idea.slug)/" class="tool-card">
              <div class="tool-icon">\(iconForCategory(idea.category))</div>
              <h3>\(idea.title)</h3>
              <p>\(idea.description)</p>
            </a>
    """
    
    // Insert before closing </div> of tools-grid
    if let range = indexContent.range(of: "</div>", options: .backwards, range: indexContent.range(of: "tools-grid")!.upperBound..<indexContent.endIndex) {
      indexContent.insert(contentsOf: "\n\(newToolEntry)\n        ", at: range.lowerBound)
      try indexContent.write(toFile: indexPath, atomically: true, encoding: .utf8)
    }
  }
  
  private func iconForCategory(_ category: String) -> String {
    switch category {
    case "game": return "🎮"
    case "visualization": return "📊"
    case "productivity": return "⚡"
    default: return "🔧"
    }
  }
  
  private func gitCommitAndPush(idea: ShipIdea) async throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/zsh")
    process.currentDirectoryURL = URL(fileURLWithPath: microtoolsPath).deletingLastPathComponent()
    process.arguments = ["-c", """
      git add -A && \
      git commit -m "Add \(idea.title) microtool (auto-generated)

      \(idea.description)
      
      Features: \(idea.features.joined(separator: ", "))
      Category: \(idea.category)
      
      🤖 Generated by Dockhand Agent" && \
      git push
      """]
    
    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe
    
    try process.run()
    process.waitUntilExit()
    
    if process.terminationStatus != 0 {
      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      let output = String(data: data, encoding: .utf8) ?? "Unknown error"
      throw ShipGeneratorError.gitFailed(output)
    }
  }
  
  private func submitToShipyard(idea: ShipIdea, proofUrl: String, apiKey: String) async throws -> String {
    let ship = try await ShipyardClient.shared.createShip(
      title: idea.title,
      description: "\(idea.description)\n\nFeatures:\n\(idea.features.map { "• \($0)" }.joined(separator: "\n"))\n\n🤖 Auto-generated by Dockhand Agent",
      proofUrl: proofUrl,
      proofType: "github_pages",
      apiKey: apiKey
    )
    return ship.id
  }
}

// MARK: - Supporting Types

struct GeneratedShip: Sendable {
  let idea: ShipIdea
  let code: MicrotoolCode
  let localPath: String
  let proofUrl: String
  let shipId: String?
}

enum ShipGeneratorError: Error, LocalizedError {
  case ideaGenerationFailed
  case codeGenerationFailed
  case fileWriteFailed
  case gitFailed(String)
  case submissionFailed
  
  var errorDescription: String? {
    switch self {
    case .ideaGenerationFailed: return "Failed to generate ship idea"
    case .codeGenerationFailed: return "Failed to generate code"
    case .fileWriteFailed: return "Failed to write files"
    case .gitFailed(let msg): return "Git operation failed: \(msg)"
    case .submissionFailed: return "Failed to submit to Shipyard"
    }
  }
}
