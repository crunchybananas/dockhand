//
//  LLMService.swift
//  Dockhand
//
//  Created by Cory Loken on 2/2/26.
//
//  LLM integration for intelligent agent decisions and code generation
//

import Foundation

// MARK: - LLM Provider Protocol

protocol LLMProvider: Sendable {
  func complete(prompt: String, systemPrompt: String?, maxTokens: Int) async throws -> String
}

// MARK: - OpenAI Provider

actor OpenAIProvider: LLMProvider {
  private let apiKey: String
  private let model: String
  private let session: URLSession
  
  init(apiKey: String, model: String = "gpt-4o-mini") {
    self.apiKey = apiKey
    self.model = model
    self.session = URLSession.shared
  }
  
  func complete(prompt: String, systemPrompt: String? = nil, maxTokens: Int = 2048) async throws -> String {
    var messages: [[String: String]] = []
    
    if let system = systemPrompt {
      messages.append(["role": "system", "content": system])
    }
    messages.append(["role": "user", "content": prompt])
    
    let body: [String: Any] = [
      "model": model,
      "messages": messages,
      "max_tokens": maxTokens,
      "temperature": 0.7
    ]
    
    var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
    request.httpMethod = "POST"
    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (data, response) = try await session.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      throw LLMError.requestFailed
    }
    
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let choices = json["choices"] as? [[String: Any]],
          let first = choices.first,
          let message = first["message"] as? [String: Any],
          let content = message["content"] as? String else {
      throw LLMError.invalidResponse
    }
    
    return content
  }
}

// MARK: - Anthropic Provider

actor AnthropicProvider: LLMProvider {
  private let apiKey: String
  private let model: String
  private let session: URLSession
  
  init(apiKey: String, model: String = "claude-3-5-sonnet-20241022") {
    self.apiKey = apiKey
    self.model = model
    self.session = URLSession.shared
  }
  
  func complete(prompt: String, systemPrompt: String? = nil, maxTokens: Int = 2048) async throws -> String {
    var body: [String: Any] = [
      "model": model,
      "max_tokens": maxTokens,
      "messages": [["role": "user", "content": prompt]]
    ]
    
    if let system = systemPrompt {
      body["system"] = system
    }
    
    var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
    request.httpMethod = "POST"
    request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    
    let (data, response) = try await session.data(for: request)
    
    guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
      throw LLMError.requestFailed
    }
    
    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
          let content = json["content"] as? [[String: Any]],
          let first = content.first,
          let text = first["text"] as? String else {
      throw LLMError.invalidResponse
    }
    
    return text
  }
}

// MARK: - LLM Error

enum LLMError: Error, LocalizedError {
  case noAPIKey
  case requestFailed
  case invalidResponse
  case rateLimited
  
  var errorDescription: String? {
    switch self {
    case .noAPIKey: return "No LLM API key configured"
    case .requestFailed: return "LLM request failed"
    case .invalidResponse: return "Invalid response from LLM"
    case .rateLimited: return "Rate limited by LLM provider"
    }
  }
}

// MARK: - LLM Service

@MainActor
final class LLMService: Sendable {
  private let keychainKey = "llm_api_key"
  
  var hasAPIKey: Bool {
    KeychainService.get(key: keychainKey) != nil
  }
  
  func setAPIKey(_ key: String) throws {
    try KeychainService.save(key: keychainKey, value: key)
  }
  
  func deleteAPIKey() throws {
    try KeychainService.delete(key: keychainKey)
  }
  
  func getProvider(config: AgentConfig) -> (any LLMProvider)? {
    guard let apiKey = KeychainService.get(key: keychainKey) else {
      return nil
    }
    
    switch config.llmProvider {
    case "anthropic":
      return AnthropicProvider(apiKey: apiKey, model: config.llmModel)
    default:
      return OpenAIProvider(apiKey: apiKey, model: config.llmModel)
    }
  }
  
  // MARK: - Comment Generation
  
  func generateComment(for post: Post, config: AgentConfig) async throws -> String {
    guard let provider = getProvider(config: config) else {
      throw LLMError.noAPIKey
    }
    
    let systemPrompt = """
    You are a friendly AI agent participating in The Shipyard community. 
    Generate a brief, genuine comment (1-2 sentences) for a post.
    Be encouraging but not over-the-top. Don't use excessive emojis.
    Focus on the actual content of the post.
    """
    
    let prompt = """
    Post Title: \(post.title)
    Post Content: \(post.content ?? "No content")
    Community: \(post.community ?? "general")
    
    Generate a brief, genuine comment:
    """
    
    return try await provider.complete(prompt: prompt, systemPrompt: systemPrompt, maxTokens: 150)
  }
  
  // MARK: - Ship Quality Evaluation
  
  func evaluateShip(_ ship: Ship, config: AgentConfig) async throws -> (shouldAttest: Bool, reason: String) {
    guard let provider = getProvider(config: config) else {
      throw LLMError.noAPIKey
    }
    
    let systemPrompt = """
    You are evaluating ships (projects) submitted to The Shipyard for attestation.
    Respond with JSON only: {"attest": true/false, "reason": "brief explanation"}
    Attest ships that appear genuine, functional, and beneficial.
    Reject spam, broken links, or low-effort submissions.
    """
    
    let prompt = """
    Ship Title: \(ship.title)
    Description: \(ship.description ?? "No description")
    Proof URL: \(ship.proofUrl ?? "No URL")
    
    Should this ship be attested as valid?
    """
    
    let response = try await provider.complete(prompt: prompt, systemPrompt: systemPrompt, maxTokens: 200)
    
    // Parse JSON response
    if let data = response.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let attest = json["attest"] as? Bool,
       let reason = json["reason"] as? String {
      return (attest, reason)
    }
    
    // Fallback: try to parse from text
    let shouldAttest = response.lowercased().contains("\"attest\": true") || 
                       response.lowercased().contains("\"attest\":true")
    return (shouldAttest, response)
  }
  
  // MARK: - Ship Idea Generation
  
  func generateShipIdea(existingShips: [String]) async throws -> ShipIdea? {
    guard let config = AgentService().config as AgentConfig?,
          let provider = getProvider(config: config) else {
      return nil
    }
    
    let systemPrompt = """
    You are generating ideas for useful microtools (small browser-based tools) for The Shipyard.
    Focus on tools that are:
    - Useful for developers or AI agents
    - Can be built with HTML/CSS/JavaScript only (no backend)
    - Fun, creative, or solve a real problem
    - Not duplicates of existing tools
    
    Respond with JSON only:
    {
      "title": "Tool Name",
      "description": "Brief description of what it does",
      "features": ["feature1", "feature2"],
      "category": "utility|game|visualization|productivity"
    }
    """
    
    let existingList = existingShips.isEmpty ? "None yet" : existingShips.joined(separator: ", ")
    let prompt = """
    Existing tools in the collection: \(existingList)
    
    Generate a creative new microtool idea that would be valuable to the community:
    """
    
    let response = try await provider.complete(prompt: prompt, systemPrompt: systemPrompt, maxTokens: 500)
    
    // Parse JSON response
    if let data = response.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let title = json["title"] as? String,
       let description = json["description"] as? String {
      return ShipIdea(
        title: title,
        description: description,
        features: json["features"] as? [String] ?? [],
        category: json["category"] as? String ?? "utility"
      )
    }
    
    return nil
  }
  
  // MARK: - Code Generation
  
  func generateMicrotoolCode(idea: ShipIdea) async throws -> MicrotoolCode? {
    guard let config = AgentService().config as AgentConfig?,
          let provider = getProvider(config: config) else {
      return nil
    }
    
    let systemPrompt = """
    You are generating code for a browser-based microtool.
    Generate clean, modern HTML/CSS/JavaScript code.
    Use a dark theme with good contrast.
    Make it responsive and user-friendly.
    All code must work in a single HTML file with inline CSS and JS, OR
    as separate index.html, styles.css, and app.js files.
    
    Respond with JSON:
    {
      "html": "<!DOCTYPE html>...",
      "css": "/* styles */...",
      "js": "// JavaScript code..."
    }
    """
    
    let prompt = """
    Create a microtool with these specifications:
    
    Title: \(idea.title)
    Description: \(idea.description)
    Features: \(idea.features.joined(separator: ", "))
    Category: \(idea.category)
    
    Generate the complete HTML, CSS, and JavaScript code:
    """
    
    let response = try await provider.complete(prompt: prompt, systemPrompt: systemPrompt, maxTokens: 4000)
    
    // Parse JSON response
    if let data = response.data(using: .utf8),
       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
       let html = json["html"] as? String {
      return MicrotoolCode(
        html: html,
        css: json["css"] as? String ?? "",
        js: json["js"] as? String ?? ""
      )
    }
    
    return nil
  }
}

// MARK: - Supporting Types

struct ShipIdea: Sendable {
  let title: String
  let description: String
  let features: [String]
  let category: String
  
  var slug: String {
    title.lowercased()
      .replacingOccurrences(of: " ", with: "-")
      .replacingOccurrences(of: "[^a-z0-9-]", with: "", options: .regularExpression)
  }
}

struct MicrotoolCode: Sendable {
  let html: String
  let css: String
  let js: String
}

// MARK: - Keychain Extensions

extension KeychainService {
  private static let llmService = "com.crunchybananas.dockhand.llm"
  
  static func get(key: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecAttrService as String: llmService,
      kSecReturnData as String: true
    ]
    
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    
    guard status == errSecSuccess,
          let data = result as? Data,
          let string = String(data: data, encoding: .utf8) else {
      return nil
    }
    
    return string
  }
  
  static func save(key: String, value: String) throws {
    guard let data = value.data(using: .utf8) else {
      throw KeychainError.encodingFailed
    }
    
    // Delete existing
    let deleteQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecAttrService as String: llmService
    ]
    SecItemDelete(deleteQuery as CFDictionary)
    
    // Add new
    let addQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecAttrService as String: llmService,
      kSecValueData as String: data
    ]
    
    let status = SecItemAdd(addQuery as CFDictionary, nil)
    guard status == errSecSuccess else {
      throw KeychainError.saveFailed(status)
    }
  }
  
  static func delete(key: String) throws {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrAccount as String: key,
      kSecAttrService as String: llmService
    ]
    
    let status = SecItemDelete(query as CFDictionary)
    guard status == errSecSuccess || status == errSecItemNotFound else {
      throw KeychainError.deleteFailed(status)
    }
  }
}
