//
//  ShipyardClient.swift
//  Dockhand
//
//  Created by Cory Loken on 2/1/26.
//
//  ShipyardKit - API Client for The Shipyard
//

import Foundation

actor ShipyardClient {
  static let shared = ShipyardClient()
  
  private let baseURL = "https://shipyard.bot"
  private let session: URLSession
  private let decoder: JSONDecoder
  private let encoder: JSONEncoder
  
  private init() {
    let config = URLSessionConfiguration.default
    config.timeoutIntervalForRequest = 30
    config.timeoutIntervalForResource = 60
    self.session = URLSession(configuration: config)
    
    self.decoder = JSONDecoder()
    self.decoder.keyDecodingStrategy = .convertFromSnakeCase
    self.decoder.dateDecodingStrategy = .custom { decoder in
      let container = try decoder.singleValueContainer()
      if let stringValue = try? container.decode(String.self) {
        if let date = ISO8601DateFormatter().date(from: stringValue) {
          return date
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        if let date = formatter.date(from: stringValue) {
          return date
        }
      }
      if let intValue = try? container.decode(Int.self) {
        return Date(timeIntervalSince1970: TimeInterval(intValue))
      }
      if let doubleValue = try? container.decode(Double.self) {
        return Date(timeIntervalSince1970: doubleValue)
      }
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid date format")
    }
    
    self.encoder = JSONEncoder()
    self.encoder.dateEncodingStrategy = .iso8601
  }
  
  // MARK: - Request Building
  
  private func buildRequest(
    path: String,
    method: String = "GET",
    body: (any Encodable)? = nil,
    apiKey: String? = nil
  ) throws -> URLRequest {
    guard let url = URL(string: baseURL + path) else {
      throw ShipyardError.invalidURL
    }
    
    var request = URLRequest(url: url)
    request.httpMethod = method
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Dockhand/1.0", forHTTPHeaderField: "User-Agent")
    
    if let apiKey = apiKey {
      request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
    }
    
    if let body = body {
      request.httpBody = try encoder.encode(body)
    }
    
    return request
  }
  
  private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
    let data: Data
    let response: URLResponse
    
#if DEBUG
    print("[ShipyardClient] Request: \(request.httpMethod ?? "GET") \(request.url?.absoluteString ?? "unknown")")
#endif
    
    do {
      (data, response) = try await session.data(for: request)
    } catch {
#if DEBUG
      print("[ShipyardClient] Network error: \(error)")
#endif
      throw ShipyardError.networkError(error.localizedDescription)
    }
    
    guard let httpResponse = response as? HTTPURLResponse else {
      throw ShipyardError.invalidResponse
    }
    
#if DEBUG
    print("[ShipyardClient] Response status: \(httpResponse.statusCode)")
    if let responseString = String(data: data, encoding: .utf8) {
      print("[ShipyardClient] Response body: \(responseString.prefix(500))")
    }
#endif
    
    switch httpResponse.statusCode {
    case 200...299:
      if data.isEmpty {
        throw ShipyardError.invalidResponse
      }
      do {
        return try decoder.decode(T.self, from: data)
      } catch {
#if DEBUG
        print("[ShipyardClient] Decoding error: \(error)")
#endif
        if let responseString = String(data: data, encoding: .utf8) {
          throw ShipyardError.decodingError("\(error.localizedDescription) | Body: \(responseString.prefix(300))")
        }
        throw ShipyardError.decodingError(error.localizedDescription)
      }
    case 401:
      throw ShipyardError.unauthorized
    case 404:
      throw ShipyardError.notFound
    case 409:
      if let apiError = try? decoder.decode(APIError.self, from: data) {
        let message = apiError.message ?? apiError.error ?? "Conflict"
        throw ShipyardError.conflict(message)
      }
      throw ShipyardError.conflict("Conflict")
    default:
      if let apiError = try? decoder.decode(APIError.self, from: data) {
        let message = apiError.message ?? apiError.error ?? "Server error"
        throw ShipyardError.serverError(message)
      }
      throw ShipyardError.serverError("HTTP \(httpResponse.statusCode)")
    }
  }
  
  // MARK: - Authentication
  
  /// Register a new agent and receive an API key
  func registerAgent(name: String, description: String?) async throws -> RegisterAgentResponse {
    let body = RegisterAgentRequest(name: name, description: description)
    let request = try buildRequest(path: "/api/agents/register", method: "POST", body: body)
    return try await performRequest(request)
  }
  
  /// Get current agent's profile
  func getMe(apiKey: String) async throws -> Agent {
    let request = try buildRequest(path: "/api/agents/me", apiKey: apiKey)
    let response: AgentEnvelope = try await performRequest(request)
    return response.agent
  }
  
  /// Update agent profile
  func updateAgent(description: String?, apiKey: String) async throws -> Agent {
    struct UpdateRequest: Codable, Sendable {
      let description: String?
    }
    let body = UpdateRequest(description: description)
    let request = try buildRequest(path: "/api/agents/me", method: "PATCH", body: body, apiKey: apiKey)
    return try await performRequest(request)
  }
  
  // MARK: - Posts
  
  /// Get feed of posts
  func getPosts(offset: Int = 0, limit: Int = 25, sort: String = "hot", community: String? = nil, apiKey: String) async throws -> PostsResponse {
    var path = "/api/posts?limit=\(limit)&offset=\(offset)&sort=\(sort)"
    if let community = community {
      path += "&community=\(community)"
    }
    let request = try buildRequest(path: path, apiKey: apiKey)
    let response: PostsEnvelope = try await performRequest(request)
    return PostsResponse(posts: response.posts, sort: sort)
  }
  
  /// Create a new post
  func createPost(title: String, content: String?, community: String?, postType: String?, apiKey: String) async throws -> Post {
    let body = CreatePostRequest(title: title, content: content, community: community, postType: postType)
    let request = try buildRequest(path: "/api/posts", method: "POST", body: body, apiKey: apiKey)
    return try await performRequest(request)
  }
  
  /// Get post detail with comments
  func getPostDetail(postId: String, apiKey: String) async throws -> PostDetailResponse {
    let request = try buildRequest(path: "/api/posts/\(postId)", apiKey: apiKey)
    return try await performRequest(request)
  }
  
  /// Create a comment on a post
  func createComment(postId: String, content: String, parentId: String? = nil, apiKey: String) async throws -> Comment {
    let body = CreateCommentRequest(content: content, parentId: parentId)
    let request = try buildRequest(path: "/api/posts/\(postId)/comments", method: "POST", body: body, apiKey: apiKey)
    return try await performRequest(request)
  }
  
  /// Vote on a post (1 or -1)
  func votePost(postId: String, value: Int, apiKey: String) async throws -> Post {
    let body = VoteRequest(value: value)
    let request = try buildRequest(path: "/api/posts/\(postId)/vote", method: "POST", body: body, apiKey: apiKey)
    return try await performRequest(request)
  }
  
  /// Delete a post
  func deletePost(postId: String, apiKey: String) async throws {
    let request = try buildRequest(path: "/api/posts/\(postId)", method: "DELETE", apiKey: apiKey)
    let _: EmptyResponse = try await performRequest(request)
  }
  
  // MARK: - Ships
  
  /// Get list of ships
  func getShips(status: ShipStatus? = nil, apiKey: String) async throws -> ShipsResponse {
    var path = "/api/ships"
    if let status = status {
      path += "?status=\(status.rawValue)"
    }
    let request = try buildRequest(path: path, apiKey: apiKey)
    let response: ShipsEnvelope = try await performRequest(request)
    return ShipsResponse(ships: response.ships)
  }
  
  /// Submit a new ship for verification
  func createShip(title: String, description: String?, proofUrl: String, proofType: String?, apiKey: String) async throws -> Ship {
    let body = CreateShipRequest(title: title, description: description, proofUrl: proofUrl, proofType: proofType)
    let request = try buildRequest(path: "/api/ships", method: "POST", body: body, apiKey: apiKey)
    return try await performRequest(request)
  }
  
  /// Attest (vouch for) another agent's ship
  func attestShip(shipId: String, verdict: String, apiKey: String) async throws -> Ship {
    let body = AttestShipRequest(verdict: verdict)
    let request = try buildRequest(path: "/api/ships/\(shipId)/attest", method: "POST", body: body, apiKey: apiKey)
    return try await performRequest(request)
  }
  
  // MARK: - Tokens
  
  /// Get token balance and stats
  func getTokenBalance(apiKey: String) async throws -> TokenBalance {
    let request = try buildRequest(path: "/api/tokens/balance", apiKey: apiKey)
    return try await performRequest(request)
  }
  
  /// Get token info (public)
  func getTokenInfo() async throws -> TokenInfo {
    let request = try buildRequest(path: "/api/token/info")
    return try await performRequest(request)
  }
  
  /// Get communities (public)
  func getCommunities() async throws -> CommunitiesResponse {
    let request = try buildRequest(path: "/api/communities")
    return try await performRequest(request)
  }
  
  /// Get current wallet address
  func getWallet(apiKey: String) async throws -> String? {
    struct WalletResponse: Decodable { let wallet: String? }
    let request = try buildRequest(path: "/api/agents/me/wallet", apiKey: apiKey)
    let response: WalletResponse = try await performRequest(request)
    return response.wallet
  }
  
  /// Set Solana wallet address for claiming tokens
  func setWallet(wallet: String, apiKey: String) async throws -> Agent {
    struct WalletRequest: Codable { let wallet: String }
    let body = WalletRequest(wallet: wallet)
    let request = try buildRequest(path: "/api/agents/me/wallet", method: "PUT", body: body, apiKey: apiKey)
    return try await performRequest(request)
  }
  
  /// Claim tokens to Solana wallet
  func claimTokens(amount: Double, apiKey: String) async throws -> ClaimTokensResponse {
    let body = ClaimTokensRequest(amount: amount)
    let request = try buildRequest(path: "/api/tokens/claim", method: "POST", body: body, apiKey: apiKey)
    return try await performRequest(request)
  }
}

// Helper for endpoints that return empty responses
private struct EmptyResponse: Decodable, Sendable {}

private struct AgentEnvelope: Decodable, Sendable {
  let agent: Agent
  
  enum CodingKeys: String, CodingKey {
    case agent
  }
  
  nonisolated init(from decoder: Decoder) throws {
    let container = try? decoder.container(keyedBy: CodingKeys.self)
    if let container, container.contains(.agent) {
      agent = try container.decode(Agent.self, forKey: .agent)
    } else {
      agent = try Agent(from: decoder)
    }
  }
}

private struct PostsEnvelope: Decodable, Sendable {
  let posts: [Post]
  
  enum CodingKeys: String, CodingKey { case posts }
  
  nonisolated init(from decoder: Decoder) throws {
    let container = try? decoder.container(keyedBy: CodingKeys.self)
    if let container, container.contains(.posts) {
      posts = try container.decode([Post].self, forKey: .posts)
    } else {
      posts = try [Post](from: decoder)
    }
  }
}

private struct ShipsEnvelope: Decodable, Sendable {
  let ships: [Ship]
  
  enum CodingKeys: String, CodingKey { case ships }
  
  nonisolated init(from decoder: Decoder) throws {
    let container = try? decoder.container(keyedBy: CodingKeys.self)
    if let container, container.contains(.ships) {
      ships = try container.decode([Ship].self, forKey: .ships)
    } else {
      ships = try [Ship](from: decoder)
    }
  }
}
