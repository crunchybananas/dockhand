//
//  Models.swift
//  Dockhand
//
//  ShipyardKit - API Models for The Shipyard
//

import Foundation

// MARK: - Decoding Helpers

extension KeyedDecodingContainer {
    nonisolated func decodeStringIfPresent(forKey key: Key) -> String? {
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return stringValue
        }
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return String(intValue)
        }
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return String(doubleValue)
        }
        return nil
    }
    
    nonisolated func decodeIntIfPresent(forKey key: Key) -> Int? {
        if let intValue = try? decodeIfPresent(Int.self, forKey: key) {
            return intValue
        }
        if let stringValue = try? decodeIfPresent(String.self, forKey: key) {
            return Int(stringValue)
        }
        if let doubleValue = try? decodeIfPresent(Double.self, forKey: key) {
            return Int(doubleValue)
        }
        return nil
    }
}

// MARK: - Agent

struct Agent: Decodable, Identifiable, Sendable {
    let id: String
    let name: String
    let description: String?
    let createdAt: Date?
    let karma: Int?
    let tokenBalance: Double?
    let solanaWallet: String?
    let shipCount: Int?
    let postCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, karma
        case createdAt = "created_at"
        case tokenBalance = "token_balance"
        case solanaWallet = "solana_wallet"
        case shipCount = "ship_count"
        case postCount = "post_count"
        case tokens
        case ships
        case posts
        case wallet
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringId = try? container.decodeIfPresent(String.self, forKey: .id) {
            id = stringId
        } else if let intId = try? container.decodeIfPresent(Int.self, forKey: .id) {
            id = String(intId)
        } else {
            id = UUID().uuidString
        }
        name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? "Unknown"
        description = try? container.decodeIfPresent(String.self, forKey: .description)
        createdAt = try? container.decodeIfPresent(Date.self, forKey: .createdAt)
        karma = try? container.decodeIfPresent(Int.self, forKey: .karma)
        tokenBalance =
            (try? container.decodeIfPresent(Double.self, forKey: .tokenBalance)) ??
            (try? container.decodeIfPresent(Double.self, forKey: .tokens))
        solanaWallet =
            (try? container.decodeIfPresent(String.self, forKey: .solanaWallet)) ??
            (try? container.decodeIfPresent(String.self, forKey: .wallet))
        shipCount =
            (try? container.decodeIfPresent(Int.self, forKey: .shipCount)) ??
            (try? container.decodeIfPresent(Int.self, forKey: .ships))
        postCount =
            (try? container.decodeIfPresent(Int.self, forKey: .postCount)) ??
            (try? container.decodeIfPresent(Int.self, forKey: .posts))
    }
}

struct RegisterAgentRequest: Codable, Sendable {
    let name: String
    let description: String?
}

struct RegisterAgentResponse: Decodable, Sendable {
    let agent: Agent
    let apiKey: String
    
    enum CodingKeys: String, CodingKey {
        case agent
        case apiKey = "api_key"
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        apiKey = try container.decode(String.self, forKey: .apiKey)
        if let nestedAgent = try container.decodeIfPresent(Agent.self, forKey: .agent) {
            agent = nestedAgent
        } else {
            agent = try Agent(from: decoder)
        }
    }
}

// MARK: - Posts

struct Post: Decodable, Identifiable, Sendable {
    let id: String
    let agentId: String?
    let agentName: String?
    let title: String
    let content: String?
    let community: String?
    let postType: String?
    let createdAt: Date?
    let upvotes: Int?
    let downvotes: Int?
    let userVote: Int? // -1, 0, or 1
    let score: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, title, content, community, score, upvotes, downvotes
        case postType = "post_type"
        case agentId = "agent_id"
        case agentName = "agent_name"
        case createdAt = "created_at"
        case userVote = "user_vote"
        case author
        case authorName = "author_name"
    }
    
    enum AuthorKeys: String, CodingKey {
        case id
        case name
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringId = container.decodeStringIfPresent(forKey: .id) {
            id = stringId
        } else {
            id = UUID().uuidString
        }
        title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? "Untitled"
        content = try? container.decodeIfPresent(String.self, forKey: .content)
        community = try? container.decodeIfPresent(String.self, forKey: .community)
        postType = try? container.decodeIfPresent(String.self, forKey: .postType)
        createdAt = try? container.decodeIfPresent(Date.self, forKey: .createdAt)
        upvotes = container.decodeIntIfPresent(forKey: .upvotes)
        downvotes = container.decodeIntIfPresent(forKey: .downvotes)
        userVote = container.decodeIntIfPresent(forKey: .userVote)
        score = container.decodeIntIfPresent(forKey: .score)
        agentId = container.decodeStringIfPresent(forKey: .agentId)
        if let authorContainer = try? container.nestedContainer(keyedBy: AuthorKeys.self, forKey: .author) {
            agentName = authorContainer.decodeStringIfPresent(forKey: .name)
        } else {
            agentName =
                container.decodeStringIfPresent(forKey: .agentName) ??
                container.decodeStringIfPresent(forKey: .authorName)
        }
    }
}

struct CreatePostRequest: Codable, Sendable {
    let title: String
    let content: String?
    let community: String?
    let postType: String?
    
    enum CodingKeys: String, CodingKey {
        case title, content, community
        case postType = "post_type"
    }
}

struct VoteRequest: Codable, Sendable {
    let value: Int // 1 or -1
}

struct PostsResponse: Decodable, Sendable {
    let posts: [Post]
    let sort: String?
}

// MARK: - Comments

struct Comment: Decodable, Identifiable, Sendable {
    let id: String
    let content: String
    let createdAt: Date?
    let authorName: String?
    let authorId: String?
    let parentId: String?
    let score: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, content, score
        case createdAt = "created_at"
        case author
        case authorName = "author_name"
        case authorId = "author_id"
        case parentId = "parent_id"
    }
    
    enum AuthorKeys: String, CodingKey {
        case id
        case name
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringId = container.decodeStringIfPresent(forKey: .id) {
            id = stringId
        } else {
            id = UUID().uuidString
        }
        content = (try? container.decodeIfPresent(String.self, forKey: .content)) ?? ""
        createdAt = try? container.decodeIfPresent(Date.self, forKey: .createdAt)
        score = container.decodeIntIfPresent(forKey: .score)
        parentId = container.decodeStringIfPresent(forKey: .parentId)
        if let authorContainer = try? container.nestedContainer(keyedBy: AuthorKeys.self, forKey: .author) {
            authorName = authorContainer.decodeStringIfPresent(forKey: .name)
            authorId = authorContainer.decodeStringIfPresent(forKey: .id)
        } else {
            authorName = container.decodeStringIfPresent(forKey: .authorName)
            authorId = container.decodeStringIfPresent(forKey: .authorId)
        }
    }
}

struct PostDetailResponse: Decodable, Sendable {
    let post: Post
    let comments: [Comment]
    
    enum CodingKeys: String, CodingKey { case post, comments }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let post = try? container.decode(Post.self, forKey: .post) {
            self.post = post
        } else {
            self.post = try Post(from: decoder)
        }
        comments = (try? container.decode([Comment].self, forKey: .comments)) ?? []
    }
}

struct CreateCommentRequest: Codable, Sendable {
    let content: String
    let parentId: String?
    
    enum CodingKeys: String, CodingKey {
        case content
        case parentId = "parent_id"
    }
}

// MARK: - Ships

enum ShipStatus: String, Codable, Sendable {
    case pending = "pending"
    case verified = "verified"
    case rejected = "rejected"
}

struct Ship: Decodable, Identifiable, Sendable {
    let id: String
    let agentId: String?
    let agentName: String?
    let title: String
    let description: String?
    let proofUrl: String?
    let proofType: String?
    let status: ShipStatus?
    let attestations: Int?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, status, attestations
        case agentId = "agent_id"
        case agentName = "agent_name"
        case authorName = "author_name"
        case authorNameAlt = "authorName"
        case proofUrl = "proof_url"
        case proofUrlAlt = "proofUrl"
        case proofType = "proof_type"
        case proofTypeAlt = "proofType"
        case attestationCount = "attestation_count"
        case attestationCountAlt = "attestationCount"
        case createdAt = "created_at"
        case author
    }
    
    enum AuthorKeys: String, CodingKey {
        case id
        case name
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let stringId = container.decodeStringIfPresent(forKey: .id) {
            id = stringId
        } else {
            id = UUID().uuidString
        }
        title = (try? container.decodeIfPresent(String.self, forKey: .title)) ?? "Untitled"
        description = try? container.decodeIfPresent(String.self, forKey: .description)
        proofUrl =
            (try? container.decodeIfPresent(String.self, forKey: .proofUrl)) ??
            (try? container.decodeIfPresent(String.self, forKey: .proofUrlAlt))
        proofType =
            (try? container.decodeIfPresent(String.self, forKey: .proofType)) ??
            (try? container.decodeIfPresent(String.self, forKey: .proofTypeAlt))
        status = try? container.decodeIfPresent(ShipStatus.self, forKey: .status)
        attestations =
            container.decodeIntIfPresent(forKey: .attestations) ??
            container.decodeIntIfPresent(forKey: .attestationCount) ??
            container.decodeIntIfPresent(forKey: .attestationCountAlt)
        createdAt = try? container.decodeIfPresent(Date.self, forKey: .createdAt)
        agentId = container.decodeStringIfPresent(forKey: .agentId)
        if let authorContainer = try? container.nestedContainer(keyedBy: AuthorKeys.self, forKey: .author) {
            agentName = authorContainer.decodeStringIfPresent(forKey: .name)
        } else {
            agentName =
                container.decodeStringIfPresent(forKey: .agentName) ??
                container.decodeStringIfPresent(forKey: .authorName) ??
                container.decodeStringIfPresent(forKey: .authorNameAlt)
        }
    }

    nonisolated init(
        id: String,
        agentId: String?,
        agentName: String?,
        title: String,
        description: String?,
        proofUrl: String?,
        proofType: String?,
        status: ShipStatus?,
        attestations: Int?,
        createdAt: Date?
    ) {
        self.id = id
        self.agentId = agentId
        self.agentName = agentName
        self.title = title
        self.description = description
        self.proofUrl = proofUrl
        self.proofType = proofType
        self.status = status
        self.attestations = attestations
        self.createdAt = createdAt
    }
    
    var needsMoreAttestations: Bool {
        status == .pending && (attestations ?? 0) < 3
    }
}

struct CreateShipRequest: Codable, Sendable {
    let title: String
    let description: String?
    let proofUrl: String
    let proofType: String?
    
    enum CodingKeys: String, CodingKey {
        case title, description
        case proofUrl = "proof_url"
        case proofType = "proof_type"
    }
}

struct AttestShipRequest: Codable, Sendable {
    let verdict: String
}

struct ShipsResponse: Decodable, Sendable {
    let ships: [Ship]
}

// MARK: - Tokens

struct TokenBalance: Decodable, Sendable {
    let balance: Double
    let pendingClaims: Double
    let totalEarned: Double
    let totalClaimed: Double
    let transactions: [TokenTransaction]?
    
    enum CodingKeys: String, CodingKey {
        case balance
        case pendingClaims = "pending_claims"
        case totalEarned = "total_earned"
        case totalClaimed = "total_claimed"
        case tokens
        case pending
        case earned
        case claimed
        case transactions
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        balance =
            (try? container.decodeIfPresent(Double.self, forKey: .balance)) ??
            (try? container.decodeIfPresent(Double.self, forKey: .tokens)) ??
            0
        pendingClaims =
            (try? container.decodeIfPresent(Double.self, forKey: .pendingClaims)) ??
            (try? container.decodeIfPresent(Double.self, forKey: .pending)) ??
            0
        totalEarned =
            (try? container.decodeIfPresent(Double.self, forKey: .totalEarned)) ??
            (try? container.decodeIfPresent(Double.self, forKey: .earned)) ??
            0
        totalClaimed =
            (try? container.decodeIfPresent(Double.self, forKey: .totalClaimed)) ??
            (try? container.decodeIfPresent(Double.self, forKey: .claimed)) ??
            0
        transactions = try? container.decodeIfPresent([TokenTransaction].self, forKey: .transactions)
    }
}

struct TokenTransaction: Decodable, Identifiable, Sendable {
    let id: String
    let amount: Double
    let reason: String
    let referenceType: String?
    let referenceId: String?
    let createdAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case amount, reason
        case referenceType = "reference_type"
        case referenceId = "reference_id"
        case createdAt = "created_at"
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        amount = (try? container.decodeIfPresent(Double.self, forKey: .amount)) ?? 0
        reason = (try? container.decodeIfPresent(String.self, forKey: .reason)) ?? ""
        referenceType = try? container.decodeIfPresent(String.self, forKey: .referenceType)
        referenceId = container.decodeStringIfPresent(forKey: .referenceId)
        createdAt = try? container.decodeIfPresent(Date.self, forKey: .createdAt)
        id = UUID().uuidString
    }
}

struct ClaimTokensRequest: Codable, Sendable {
    let amount: Double
}

struct ClaimTokensResponse: Codable, Sendable {
    let transactionId: String
    let amount: Double
    let newBalance: Double
    
    enum CodingKeys: String, CodingKey {
        case transactionId = "transaction_id"
        case amount
        case newBalance = "new_balance"
    }
}

struct TokenInfo: Decodable, Sendable {
    let name: String?
    let symbol: String?
    let contract: String?
    let website: String?
    let twitter: String?
    let dexscreener: String?
    let jupiter: String?
    let circulating: Double?
    
    enum CodingKeys: String, CodingKey {
        case name, symbol, contract, website, twitter, dexscreener, jupiter, circulating
    }
}

// MARK: - Communities

struct Community: Decodable, Identifiable, Sendable {
    let id: String
    let name: String
    let slug: String
    let postCount: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, slug
        case postCount = "post_count"
    }
    
    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = container.decodeStringIfPresent(forKey: .id) ?? UUID().uuidString
        name = (try? container.decodeIfPresent(String.self, forKey: .name)) ?? "Unknown"
        slug = (try? container.decodeIfPresent(String.self, forKey: .slug)) ?? name
        postCount = container.decodeIntIfPresent(forKey: .postCount)
    }
}

struct CommunitiesResponse: Decodable, Sendable {
    let communities: [Community]
}

struct SetWalletRequest: Codable, Sendable {
    let solanaWallet: String
    
    enum CodingKeys: String, CodingKey {
        case solanaWallet = "solana_wallet"
    }
}

// MARK: - API Errors

struct APIError: Codable, Sendable {
    let error: String?
    let message: String?
}

enum ShipyardError: LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case notFound
    case conflict(String)
    case serverError(String)
    case networkError(String)
    case decodingError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .unauthorized:
            return "Invalid or expired API key"
        case .notFound:
            return "Resource not found"
        case .conflict(let message):
            return message.isEmpty ? "Conflict" : message
        case .serverError(let message):
            return "Server error: \(message)"
        case .networkError(let message):
            return "Network error: \(message)"
        case .decodingError(let message):
            return "Failed to parse response: \(message)"
        }
    }
}
