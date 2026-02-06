//
//  MCPService.swift
//  Dockhand
//
//  Created by Cory Loken on 2/5/26.
//
//  MCP server integration – exposes Dockhand as an MCP tool server so
//  external agents can release ships, query the feed, and interact with
//  the Shipyard API over JSON-RPC.
//

import Foundation
import MCPServerKit
import OSLog

@Observable
@MainActor
final class MCPService {
  // MARK: - UserDefaults Keys

  private static let enabledKey = "mcp.server.enabled"
  private static let portKey = "mcp.server.port"

  // MARK: - Public State

  private(set) var isRunning: Bool = false
  var port: Int = 8766
  var lanModeEnabled: Bool = false
  var lastError: String?
  /// Whether the MCP server should auto-start on launch (persisted in UserDefaults).
  var autoStartEnabled: Bool = false

  // MARK: - Private

  private let logger = Logger(subsystem: "com.dockhand", category: "MCPService")
  private var server: MCPServer?
  private var toolHandler: DockhandToolHandler?
  private weak var appState: AppState?

  // MARK: - Init

  init() {
    let defaults = UserDefaults.standard
    let storedPort = defaults.integer(forKey: Self.portKey)
    if storedPort > 0 {
      self.port = storedPort
    }
    self.autoStartEnabled = defaults.bool(forKey: Self.enabledKey)
  }

  // MARK: - Setup

  func configure(appState: AppState) {
    self.appState = appState
  }

  /// Persist current MCP config to UserDefaults so `defaults read` and
  /// the build-and-launch script can query / set them.
  func persistSettings() {
    UserDefaults.standard.set(autoStartEnabled, forKey: Self.enabledKey)
    UserDefaults.standard.set(port, forKey: Self.portKey)
  }

  // MARK: - Lifecycle

  func start() {
    guard !isRunning, let appState else {
      logger.warning("Cannot start MCP server – missing appState or already running")
      return
    }

    let registry = MCPToolRegistry()
    registerToolDefinitions(registry: registry)

    let handler = DockhandToolHandler(appState: appState)
    registry.register(handler: handler)
    self.toolHandler = handler

    let srv = MCPServer(port: port, lanModeEnabled: lanModeEnabled, registry: registry)
    srv.start()
    self.server = srv
    isRunning = srv.isRunning
    lastError = srv.lastError
    logger.info("MCP server started on port \(self.port)")
  }

  func stop() {
    server?.stop()
    server = nil
    toolHandler = nil
    isRunning = false
    lastError = nil
    logger.info("MCP server stopped")
  }

  func restart() {
    stop()
    start()
  }

  func setPort(_ newPort: Int) {
    port = newPort
    server?.setPort(newPort)
    isRunning = server?.isRunning ?? false
  }

  func setLanMode(_ enabled: Bool) {
    lanModeEnabled = enabled
    server?.setLanMode(enabled)
    isRunning = server?.isRunning ?? false
  }

  // MARK: - Tool Registration

  private func registerToolDefinitions(registry: MCPToolRegistry) {
    registry.register([
      // Ship management
      MCPToolDefinition(
        name: "dockhand.release_ship",
        description: "Release (create) a new ship on Shipyard. Requires a title, proof URL, and optional description and proof type.",
        inputSchema: [
          "type": "object",
          "properties": [
            "title": ["type": "string", "description": "Title of the ship"],
            "description": ["type": "string", "description": "Optional description of what was shipped"],
            "proof_url": ["type": "string", "description": "URL proving the work (e.g. GitHub Pages link, commit URL)"],
            "proof_type": ["type": "string", "description": "Type of proof: github, url, screenshot, or demo"]
          ],
          "required": ["title", "proof_url"]
        ],
        category: .state,
        isMutating: true
      ),

      MCPToolDefinition(
        name: "dockhand.list_ships",
        description: "List ships from The Shipyard. Optionally filter by status (pending, verified, rejected).",
        inputSchema: [
          "type": "object",
          "properties": [
            "status": ["type": "string", "enum": ["pending", "verified", "rejected"], "description": "Filter by ship status"],
            "mine_only": ["type": "boolean", "description": "If true, only return the current agent's ships"]
          ]
        ],
        category: .state,
        isMutating: false
      ),

      MCPToolDefinition(
        name: "dockhand.get_ship",
        description: "Get details for a specific ship by its ID.",
        inputSchema: [
          "type": "object",
          "properties": [
            "ship_id": ["type": "string", "description": "The ID of the ship to look up"]
          ],
          "required": ["ship_id"]
        ],
        category: .state,
        isMutating: false
      ),

      MCPToolDefinition(
        name: "dockhand.attest_ship",
        description: "Attest (vouch for) another agent's ship. Verdict must be 'legitimate' or 'suspicious'.",
        inputSchema: [
          "type": "object",
          "properties": [
            "ship_id": ["type": "string", "description": "The ID of the ship to attest"],
            "verdict": ["type": "string", "enum": ["legitimate", "suspicious"], "description": "Attestation verdict"]
          ],
          "required": ["ship_id", "verdict"]
        ],
        category: .state,
        isMutating: true
      ),

      // Feed / Posts
      MCPToolDefinition(
        name: "dockhand.list_posts",
        description: "List posts from The Shipyard feed. Supports sort and community filters.",
        inputSchema: [
          "type": "object",
          "properties": [
            "sort": ["type": "string", "enum": ["hot", "new", "top"], "description": "Sort order (default: hot)"],
            "community": ["type": "string", "description": "Filter by community slug"],
            "limit": ["type": "integer", "description": "Max posts to return (default: 25)"]
          ]
        ],
        category: .state,
        isMutating: false
      ),

      MCPToolDefinition(
        name: "dockhand.create_post",
        description: "Create a new post on The Shipyard feed.",
        inputSchema: [
          "type": "object",
          "properties": [
            "title": ["type": "string", "description": "Post title"],
            "content": ["type": "string", "description": "Post body / content"],
            "community": ["type": "string", "description": "Community slug to post in"],
            "post_type": ["type": "string", "description": "Post type"]
          ],
          "required": ["title"]
        ],
        category: .state,
        isMutating: true
      ),

      // Profile & Tokens
      MCPToolDefinition(
        name: "dockhand.get_profile",
        description: "Get the current agent's profile information including name, karma, ship count, and post count.",
        inputSchema: ["type": "object", "properties": [:]],
        category: .state,
        isMutating: false
      ),

      MCPToolDefinition(
        name: "dockhand.get_balance",
        description: "Get the current agent's $SHIPYARD token balance, pending claims, and earnings.",
        inputSchema: ["type": "object", "properties": [:]],
        category: .state,
        isMutating: false
      ),

      // Generate ship (autonomous)
      MCPToolDefinition(
        name: "dockhand.generate_ship",
        description: "Autonomously generate a new microtool ship using the LLM, commit & push it, and optionally submit it to Shipyard.",
        inputSchema: [
          "type": "object",
          "properties": [
            "submit": ["type": "boolean", "description": "If true, auto-submit the ship to Shipyard after generation (default: false)"]
          ]
        ],
        category: .state,
        isMutating: true
      ),
    ])
  }
}
