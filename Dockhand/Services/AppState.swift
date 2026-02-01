//
//  AppState.swift
//  Dockhand
//
//  Central state management using @Observable (iOS 17+ / macOS 14+)
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class AppState {
    // MARK: - Authentication State
    
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var currentAgent: Agent?
    var tokenBalance: TokenBalance?
    var walletAddress: String?
    var tokenInfo: TokenInfo?
    var communities: [Community] = []
    
    // MARK: - Feed State
    
    var posts: [Post] = []
    var postsOffset: Int = 0
    var isLoadingPosts: Bool = false
    var hasMorePosts: Bool = true
    var feedSort: String = "hot"
    var feedCommunity: String? = nil
    
    // MARK: - Ships State
    
    var ships: [Ship] = []
    var myShips: [Ship] = []
    var shipsOffset: Int = 0
    var isLoadingShips: Bool = false

    private(set) var myShipIds: Set<String> = []

    // MARK: - Local Attest Cache

    private let attestedKey = "attested_ship_ids"
    var attestedShipIds: Set<String> = []
    
    // MARK: - Error Handling
    
    var errorMessage: String?
    var showError: Bool = false
    
    // MARK: - API Key
    
    private var apiKey: String? {
        KeychainService.getAPIKey()
    }

    private func normalizedAPIKey(_ input: String?) -> String? {
        guard let raw = input?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        if raw.lowercased().hasPrefix("bearer ") {
            let start = raw.index(raw.startIndex, offsetBy: 7)
            let trimmed = String(raw[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
        return raw
    }
    
    // MARK: - Initialization
    
    init() {
        if let saved = UserDefaults.standard.array(forKey: attestedKey) as? [String] {
            attestedShipIds = Set(saved)
        }
        // Check for existing API key on launch
        if KeychainService.hasAPIKey {
            Task {
                await checkAuthentication()
            }
        }
    }
    
    // MARK: - Authentication
    
    func checkAuthentication() async {
        guard let apiKey = normalizedAPIKey(apiKey) else {
            isAuthenticated = false
            return
        }
        
        isLoading = true
        defer { isLoading = false }
        
        do {
            currentAgent = try await ShipyardClient.shared.getMe(apiKey: apiKey)
            tokenBalance = try await ShipyardClient.shared.getTokenBalance(apiKey: apiKey)
            isAuthenticated = true
        } catch {
            // Invalid API key - clear it
            try? KeychainService.deleteAPIKey()
            isAuthenticated = false
            handleError(error)
        }
    }
    
    func registerAgent(name: String, description: String?) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let response = try await ShipyardClient.shared.registerAgent(name: name, description: description)
            let keyToStore = normalizedAPIKey(response.apiKey) ?? response.apiKey
            try KeychainService.saveAPIKey(keyToStore)
            currentAgent = response.agent
            tokenBalance = try await ShipyardClient.shared.getTokenBalance(apiKey: keyToStore)
            isAuthenticated = true
            return true
        } catch {
            handleError(error)
            return false
        }
    }
    
    func loginWithAPIKey(_ apiKey: String) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        
        do {
            guard let normalized = normalizedAPIKey(apiKey) else {
                throw ShipyardError.unauthorized
            }
            // Validate the API key by fetching the agent
            let agent = try await ShipyardClient.shared.getMe(apiKey: normalized)
            try KeychainService.saveAPIKey(normalized)
            currentAgent = agent
            tokenBalance = try await ShipyardClient.shared.getTokenBalance(apiKey: normalized)
            isAuthenticated = true
            return true
        } catch {
            handleError(error)
            return false
        }
    }
    
    func logout() {
        try? KeychainService.deleteAPIKey()
        isAuthenticated = false
        currentAgent = nil
        tokenBalance = nil
        posts = []
        ships = []
        myShips = []
    }
    
    // MARK: - Profile
    
    func refreshProfile() async {
        guard let apiKey = apiKey else { return }
        
        do {
            async let agentTask = ShipyardClient.shared.getMe(apiKey: apiKey)
            async let balanceTask = ShipyardClient.shared.getTokenBalance(apiKey: apiKey)
            async let walletTask = ShipyardClient.shared.getWallet(apiKey: apiKey)
            async let tokenInfoTask = ShipyardClient.shared.getTokenInfo()
            async let communitiesTask = ShipyardClient.shared.getCommunities()
            
            let (agent, balance, wallet, tokenInfo, communitiesResponse) = try await (agentTask, balanceTask, walletTask, tokenInfoTask, communitiesTask)
            currentAgent = agent
            tokenBalance = balance
            walletAddress = wallet
            self.tokenInfo = tokenInfo
            self.communities = communitiesResponse.communities
            if let transactions = balance.transactions {
                let attested: [String] = transactions.compactMap { txn in
                    guard txn.reason == "attestation_given", txn.referenceType == "ship" else { return nil }
                    return txn.referenceId
                }
                if !attested.isEmpty {
                    attestedShipIds.formUnion(attested)
                    UserDefaults.standard.set(Array(attestedShipIds), forKey: attestedKey)
                }
            }
        } catch {
            handleError(error)
        }
    }
    
    // MARK: - Posts
    
    func loadPosts(refresh: Bool = false) async {
        guard let apiKey = apiKey else { return }
        
        if refresh {
            postsOffset = 0
            hasMorePosts = true
        }
        
        isLoadingPosts = true
        defer { isLoadingPosts = false }
        
        do {
            let response = try await ShipyardClient.shared.getPosts(offset: postsOffset, sort: feedSort, community: feedCommunity, apiKey: apiKey)
            if response.posts.isEmpty {
                hasMorePosts = false
                return
            }

            if refresh {
                posts = response.posts
            } else {
                let existingIds = Set(posts.map { $0.id })
                let newPosts = response.posts.filter { !existingIds.contains($0.id) }
                if newPosts.isEmpty {
                    hasMorePosts = false
                } else {
                    posts.append(contentsOf: newPosts)
                }
            }
            postsOffset += response.posts.count
        } catch {
            handleError(error)
        }
    }
    
    func createPost(title: String, content: String?, community: String?, postType: String?) async -> Bool {
        guard let apiKey = apiKey else { return false }
        
        do {
            let post = try await ShipyardClient.shared.createPost(title: title, content: content, community: community, postType: postType, apiKey: apiKey)
            posts.insert(post, at: 0)
            return true
        } catch {
            handleError(error)
            return false
        }
    }

    // MARK: - Post Detail
    
    func loadPostDetail(postId: String) async -> PostDetailResponse? {
        guard let apiKey = apiKey else { return nil }
        do {
            return try await ShipyardClient.shared.getPostDetail(postId: postId, apiKey: apiKey)
        } catch {
            handleError(error)
            return nil
        }
    }
    
    func createComment(postId: String, content: String, parentId: String? = nil) async -> Comment? {
        guard let apiKey = apiKey else { return nil }
        do {
            return try await ShipyardClient.shared.createComment(postId: postId, content: content, parentId: parentId, apiKey: apiKey)
        } catch {
            handleError(error)
            return nil
        }
    }
    
    func votePost(_ postId: String, vote: Int) async {
        guard let apiKey = apiKey else { return }
        
        do {
            let updatedPost = try await ShipyardClient.shared.votePost(postId: postId, value: vote, apiKey: apiKey)
            if let index = posts.firstIndex(where: { $0.id == postId }) {
                posts[index] = updatedPost
            }
        } catch {
            handleError(error)
        }
    }
    
    func deletePost(_ postId: String) async -> Bool {
        guard let apiKey = apiKey else { return false }
        
        do {
            try await ShipyardClient.shared.deletePost(postId: postId, apiKey: apiKey)
            posts.removeAll { $0.id == postId }
            return true
        } catch {
            handleError(error)
            return false
        }
    }
    
    // MARK: - Ships
    
    func loadShips(status: ShipStatus? = nil, refresh: Bool = false) async {
        guard let apiKey = apiKey else { return }
        
        if refresh {
            shipsOffset = 0
        }
        
        isLoadingShips = true
        defer { isLoadingShips = false }
        
        do {
            let response = try await ShipyardClient.shared.getShips(status: status, apiKey: apiKey)
            if refresh {
                ships = response.ships
            } else {
                ships.append(contentsOf: response.ships)
            }
            shipsOffset += response.ships.count
        } catch {
            handleError(error)
        }
    }
    
    func loadMyShips() async {
        guard let apiKey = apiKey else { return }
        
        do {
            let response = try await ShipyardClient.shared.getShips(status: nil, apiKey: apiKey)
            if let agentId = currentAgent?.id {
                myShips = response.ships.filter { $0.agentId == agentId }
            } else {
                myShips = []
            }
            myShipIds = Set(myShips.map { $0.id })
        } catch {
            handleError(error)
        }
    }
    
    func createShip(title: String, description: String?, proofUrl: String, proofType: String?) async -> Bool {
        guard let apiKey = apiKey else { return false }
        
        do {
            let ship = try await ShipyardClient.shared.createShip(
                title: title,
                description: description,
                proofUrl: proofUrl,
                proofType: proofType,
                apiKey: apiKey
            )
            let merged = Ship(
                id: ship.id,
                agentId: ship.agentId ?? currentAgent?.id,
                agentName: ship.agentName ?? currentAgent?.name,
                title: ship.title.isEmpty ? title : ship.title,
                description: ship.description ?? description,
                proofUrl: ship.proofUrl ?? proofUrl,
                proofType: ship.proofType ?? proofType,
                status: ship.status ?? .pending,
                attestations: ship.attestations ?? 0,
                createdAt: ship.createdAt ?? Date()
            )
            myShips.insert(merged, at: 0)
            myShipIds.insert(merged.id)
            return true
        } catch {
            handleError(error)
            return false
        }
    }
    
    func attestShip(_ shipId: String, verdict: String) async -> Bool {
        guard let apiKey = apiKey else { return false }
        
        do {
            let updatedShip = try await ShipyardClient.shared.attestShip(shipId: shipId, verdict: verdict, apiKey: apiKey)
            if let index = ships.firstIndex(where: { $0.id == shipId }) {
                ships[index] = updatedShip
            }
            attestedShipIds.insert(shipId)
            UserDefaults.standard.set(Array(attestedShipIds), forKey: attestedKey)
            // Attesting earns +5 tokens
            await refreshProfile()
            return true
        } catch {
            if case ShipyardError.conflict = error {
                attestedShipIds.insert(shipId)
                UserDefaults.standard.set(Array(attestedShipIds), forKey: attestedKey)
            }
            handleError(error)
            return false
        }
    }

    func hasAttested(_ shipId: String) -> Bool {
        attestedShipIds.contains(shipId)
    }

    func isOwnShip(_ ship: Ship) -> Bool {
        myShipIds.contains(ship.id) || ship.agentId == currentAgent?.id || ship.agentName == currentAgent?.name
    }
    
    // MARK: - Tokens
    
    func setWallet(_ walletAddress: String) async -> Bool {
        guard let apiKey = apiKey else { return false }
        
        do {
            currentAgent = try await ShipyardClient.shared.setWallet(wallet: walletAddress, apiKey: apiKey)
            self.walletAddress = walletAddress
            return true
        } catch {
            handleError(error)
            return false
        }
    }
    
    func claimTokens(amount: Double) async -> ClaimTokensResponse? {
        guard let apiKey = apiKey else { return nil }
        
        do {
            let response = try await ShipyardClient.shared.claimTokens(amount: amount, apiKey: apiKey)
            // Refresh balance after claim
            tokenBalance = try await ShipyardClient.shared.getTokenBalance(apiKey: apiKey)
            return response
        } catch {
            handleError(error)
            return nil
        }
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) {
        errorMessage = error.localizedDescription
        showError = true
    }
    
    func clearError() {
        errorMessage = nil
        showError = false
    }
}
