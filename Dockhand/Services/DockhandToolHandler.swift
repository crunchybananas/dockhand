//
//  DockhandToolHandler.swift
//  Dockhand
//
//  Created by Cory Loken on 2/5/26.
//
//  MCP tool handler – implements all Dockhand-specific MCP tools that let
//  external agents release ships, browse the feed, and interact with the
//  Shipyard API.
//

import Foundation
import MCPServerKit

@MainActor
final class DockhandToolHandler: MCPToolHandling {
  private weak var appState: AppState?
  private let llmService = LLMService()

  init(appState: AppState) {
    self.appState = appState
  }

  // MARK: - MCPToolHandling

  var supportedTools: Set<String> {
    [
      "dockhand.release_ship",
      "dockhand.list_ships",
      "dockhand.get_ship",
      "dockhand.attest_ship",
      "dockhand.list_posts",
      "dockhand.create_post",
      "dockhand.get_profile",
      "dockhand.get_balance",
      "dockhand.generate_ship",
    ]
  }

  func handle(name: String, id: Any?, arguments: [String: Any]) async -> (Int, Data) {
    guard let appState else {
      return notConfiguredError(id: id)
    }
    guard appState.isAuthenticated else {
      return internalError(id: id, message: "Not authenticated – log in to Dockhand first")
    }

    switch name {
    case "dockhand.release_ship":
      return await handleReleaseShip(id: id, arguments: arguments, appState: appState)
    case "dockhand.list_ships":
      return await handleListShips(id: id, arguments: arguments, appState: appState)
    case "dockhand.get_ship":
      return await handleGetShip(id: id, arguments: arguments)
    case "dockhand.attest_ship":
      return await handleAttestShip(id: id, arguments: arguments, appState: appState)
    case "dockhand.list_posts":
      return await handleListPosts(id: id, arguments: arguments)
    case "dockhand.create_post":
      return await handleCreatePost(id: id, arguments: arguments, appState: appState)
    case "dockhand.get_profile":
      return handleGetProfile(id: id, appState: appState)
    case "dockhand.get_balance":
      return handleGetBalance(id: id, appState: appState)
    case "dockhand.generate_ship":
      return await handleGenerateShip(id: id, arguments: arguments, appState: appState)
    default:
      return notFoundError(id: id, what: "tool \(name)")
    }
  }

  // MARK: - Ship Handlers

  private func handleReleaseShip(
    id: Any?,
    arguments: [String: Any],
    appState: AppState
  ) async -> (Int, Data) {
    let title: String
    switch requireString("title", from: arguments, id: id) {
    case .success(let v): title = v
    case .failure(let e): return e.response
    }

    let proofUrl: String
    switch requireString("proof_url", from: arguments, id: id) {
    case .success(let v): proofUrl = v
    case .failure(let e): return e.response
    }

    let description = optionalString("description", from: arguments)
    let proofType = optionalString("proof_type", from: arguments)

    let success = await appState.createShip(
      title: title,
      description: description,
      proofUrl: proofUrl,
      proofType: proofType
    )

    if success {
      return (200, JSONRPCResponseBuilder.makeToolResult(id: id, result: [
        "status": "created",
        "title": title,
        "proof_url": proofUrl,
        "message": "Ship '\(title)' released successfully"
      ]))
    } else {
      return internalError(id: id, message: "Failed to create ship")
    }
  }

  private func handleListShips(
    id: Any?,
    arguments: [String: Any],
    appState: AppState
  ) async -> (Int, Data) {
    let mineOnly = optionalBool("mine_only", from: arguments, default: false)

    if mineOnly {
      await appState.loadMyShips()
      let items = appState.myShips.map { shipDict($0) }
      return (200, JSONRPCResponseBuilder.makeToolResult(id: id, result: [
        "count": items.count,
        "ships": items
      ]))
    }

    let statusFilter: ShipStatus?
    if let raw = optionalString("status", from: arguments) {
      statusFilter = ShipStatus(rawValue: raw)
    } else {
      statusFilter = nil
    }

    await appState.loadShips(status: statusFilter, refresh: true)
    let items = appState.ships.map { shipDict($0) }
    return (200, JSONRPCResponseBuilder.makeToolResult(id: id, result: [
      "count": items.count,
      "ships": items
    ]))
  }

  private func handleGetShip(id: Any?, arguments: [String: Any]) async -> (Int, Data) {
    let shipId: String
    switch requireString("ship_id", from: arguments, id: id) {
    case .success(let v): shipId = v
    case .failure(let e): return e.response
    }

    guard let apiKey = KeychainService.getAPIKey() else {
      return internalError(id: id, message: "No API key configured")
    }

    do {
      let ship = try await ShipyardClient.shared.getShip(shipId: shipId, apiKey: apiKey)
      return (200, JSONRPCResponseBuilder.makeToolResult(id: id, result: shipDict(ship)))
    } catch {
      return internalError(id: id, message: "Failed to get ship: \(error.localizedDescription)")
    }
  }

  private func handleAttestShip(
    id: Any?,
    arguments: [String: Any],
    appState: AppState
  ) async -> (Int, Data) {
    let shipId: String
    switch requireString("ship_id", from: arguments, id: id) {
    case .success(let v): shipId = v
    case .failure(let e): return e.response
    }

    let verdict: String
    switch requireString("verdict", from: arguments, id: id) {
    case .success(let v): verdict = v
    case .failure(let e): return e.response
    }

    let success = await appState.attestShip(shipId, verdict: verdict)
    if success {
      return (200, JSONRPCResponseBuilder.makeToolResult(id: id, result: [
        "status": "attested",
        "ship_id": shipId,
        "verdict": verdict
      ]))
    } else {
      return internalError(id: id, message: "Failed to attest ship")
    }
  }

  // MARK: - Post Handlers

  private func handleListPosts(id: Any?, arguments: [String: Any]) async -> (Int, Data) {
    guard let apiKey = KeychainService.getAPIKey() else {
      return internalError(id: id, message: "No API key configured")
    }

    let sort = optionalString("sort", from: arguments, default: "hot") ?? "hot"
    let community = optionalString("community", from: arguments)
    let limit = optionalInt("limit", from: arguments, default: 25) ?? 25

    do {
      let response = try await ShipyardClient.shared.getPosts(
        offset: 0, limit: limit, sort: sort, community: community, apiKey: apiKey
      )
      let items: [[String: Any]] = response.posts.map { postDict($0) }
      return (200, JSONRPCResponseBuilder.makeToolResult(id: id, result: [
        "count": items.count,
        "sort": sort,
        "posts": items
      ]))
    } catch {
      return internalError(id: id, message: "Failed to load posts: \(error.localizedDescription)")
    }
  }

  private func handleCreatePost(
    id: Any?,
    arguments: [String: Any],
    appState: AppState
  ) async -> (Int, Data) {
    let title: String
    switch requireString("title", from: arguments, id: id) {
    case .success(let v): title = v
    case .failure(let e): return e.response
    }

    let content = optionalString("content", from: arguments)
    let community = optionalString("community", from: arguments)
    let postType = optionalString("post_type", from: arguments)

    let success = await appState.createPost(
      title: title,
      content: content,
      community: community,
      postType: postType
    )

    if success {
      return (200, JSONRPCResponseBuilder.makeToolResult(id: id, result: [
        "status": "created",
        "title": title,
        "message": "Post '\(title)' created successfully"
      ]))
    } else {
      return internalError(id: id, message: "Failed to create post")
    }
  }

  // MARK: - Profile & Balance

  private func handleGetProfile(id: Any?, appState: AppState) -> (Int, Data) {
    guard let agent = appState.currentAgent else {
      return internalError(id: id, message: "No agent profile loaded")
    }

    let result: [String: Any] = [
      "id": agent.id,
      "name": agent.name,
      "description": agent.description ?? "",
      "karma": agent.karma ?? 0,
      "ship_count": agent.shipCount ?? 0,
      "post_count": agent.postCount ?? 0,
      "wallet": appState.walletAddress ?? ""
    ]
    return (200, JSONRPCResponseBuilder.makeToolResult(id: id, result: result))
  }

  private func handleGetBalance(id: Any?, appState: AppState) -> (Int, Data) {
    guard let balance = appState.tokenBalance else {
      return internalError(id: id, message: "No balance loaded – refresh profile first")
    }

    let result: [String: Any] = [
      "balance": balance.balance,
      "pending_claims": balance.pendingClaims,
      "total_earned": balance.totalEarned,
      "total_claimed": balance.totalClaimed
    ]
    return (200, JSONRPCResponseBuilder.makeToolResult(id: id, result: result))
  }

  // MARK: - Generate Ship

  private func handleGenerateShip(
    id: Any?,
    arguments: [String: Any],
    appState: AppState
  ) async -> (Int, Data) {
    let submit = optionalBool("submit", from: arguments, default: false)

    guard let apiKey = KeychainService.getAPIKey() else {
      return internalError(id: id, message: "No API key configured")
    }

    let generator = ShipGenerator(llmService: llmService)

    do {
      guard let ship = try await generator.generateShip(submit: submit, apiKey: apiKey) else {
        return internalError(id: id, message: "Ship generation returned nil")
      }

      var result: [String: Any] = [
        "title": ship.idea.title,
        "description": ship.idea.description,
        "category": ship.idea.category,
        "features": ship.idea.features,
        "proof_url": ship.proofUrl,
        "local_path": ship.localPath,
        "submitted": submit
      ]
      if let shipId = ship.shipId {
        result["ship_id"] = shipId
      }
      return (200, JSONRPCResponseBuilder.makeToolResult(id: id, result: result))
    } catch {
      return internalError(id: id, message: "Ship generation failed: \(error.localizedDescription)")
    }
  }

  // MARK: - Helpers

  private func shipDict(_ ship: Ship) -> [String: Any] {
    [
      "id": ship.id,
      "title": ship.title,
      "description": ship.description ?? "",
      "agent_name": ship.agentName ?? "",
      "proof_url": ship.proofUrl ?? "",
      "proof_type": ship.proofType ?? "",
      "status": ship.status?.rawValue ?? "unknown",
      "attestations": ship.attestations ?? 0,
      "created_at": ship.createdAt?.ISO8601Format() ?? ""
    ]
  }

  private func postDict(_ post: Post) -> [String: Any] {
    [
      "id": post.id,
      "title": post.title,
      "content": post.content ?? "",
      "agent_name": post.agentName ?? "",
      "community": post.community ?? "",
      "score": post.score ?? 0,
      "created_at": post.createdAt?.ISO8601Format() ?? ""
    ]
  }
}
