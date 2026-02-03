//
//  AgentService.swift
//  Dockhand
//
//  Created by Cory Loken on 2/2/26.
//
//  Autonomous agent service that monitors Shipyard, engages with posts/ships,
//  and can create new ships - all while respecting karma limits.
//

import Foundation

// MARK: - Activity Ledger (Karma Tracking)

/// Tracks actions to enforce Shipyard's rate limits:
/// - Max 5 posts per hour
/// - Max 10 comments per hour
/// - 90% karma penalty if exceeded
struct ActivityLedger: Codable, Sendable {
  var posts: [Date] = []
  var comments: [Date] = []
  var attestations: [Date] = []
  var shipCreations: [Date] = []
  
  private let postsPerHour = 5
  private let commentsPerHour = 10
  private let attestationsPerHour = 20  // Conservative limit
  private let shipCreationsPerDay = 3   // Don't spam ships
  
  mutating func pruneOld() {
    let oneHourAgo = Date().addingTimeInterval(-3600)
    let oneDayAgo = Date().addingTimeInterval(-86400)
    posts = posts.filter { $0 > oneHourAgo }
    comments = comments.filter { $0 > oneHourAgo }
    attestations = attestations.filter { $0 > oneHourAgo }
    shipCreations = shipCreations.filter { $0 > oneDayAgo }
  }
  
  func canPost() -> Bool {
    let oneHourAgo = Date().addingTimeInterval(-3600)
    return posts.filter { $0 > oneHourAgo }.count < postsPerHour
  }
  
  func canComment() -> Bool {
    let oneHourAgo = Date().addingTimeInterval(-3600)
    return comments.filter { $0 > oneHourAgo }.count < commentsPerHour
  }
  
  func canAttest() -> Bool {
    let oneHourAgo = Date().addingTimeInterval(-3600)
    return attestations.filter { $0 > oneHourAgo }.count < attestationsPerHour
  }
  
  func canCreateShip() -> Bool {
    let oneDayAgo = Date().addingTimeInterval(-86400)
    return shipCreations.filter { $0 > oneDayAgo }.count < shipCreationsPerDay
  }
  
  mutating func recordPost() { posts.append(Date()) }
  mutating func recordComment() { comments.append(Date()) }
  mutating func recordAttestation() { attestations.append(Date()) }
  mutating func recordShipCreation() { shipCreations.append(Date()) }
}

// MARK: - Agent Configuration

struct AgentConfig: Codable, Sendable {
  enum Aggressiveness: String, Codable, CaseIterable, Sendable {
    case conservative  // Rarely engages, only obvious wins
    case moderate      // Balanced engagement
    case aggressive    // Engages frequently within limits
  }
  
  var enabled: Bool = false
  var aggressiveness: Aggressiveness = .moderate
  var monitorIntervalMinutes: Int = 15
  var autoAttest: Bool = true
  var autoComment: Bool = true
  var autoCreateShips: Bool = false  // Disabled by default - powerful feature
  var llmProvider: String = "openai"
  var llmModel: String = "gpt-4o-mini"
}

// MARK: - Seen Items Tracker

struct SeenItems: Codable, Sendable {
  var postIds: Set<String> = []
  var shipIds: Set<String> = []
  
  mutating func markSeen(postId: String) { postIds.insert(postId) }
  mutating func markSeen(shipId: String) { shipIds.insert(shipId) }
  func hasSeen(postId: String) -> Bool { postIds.contains(postId) }
  func hasSeen(shipId: String) -> Bool { shipIds.contains(shipId) }
}

// MARK: - Agent Action Log

struct AgentAction: Codable, Identifiable, Sendable {
  let id: UUID
  let timestamp: Date
  let type: ActionType
  let targetId: String
  let targetTitle: String
  let detail: String
  let success: Bool
  
  enum ActionType: String, Codable, Sendable {
    case attestation
    case comment
    case post
    case shipCreation
    case monitoring
  }
  
  init(type: ActionType, targetId: String, targetTitle: String, detail: String, success: Bool) {
    self.id = UUID()
    self.timestamp = Date()
    self.type = type
    self.targetId = targetId
    self.targetTitle = targetTitle
    self.detail = detail
    self.success = success
  }
}

// MARK: - Agent Service

@Observable
@MainActor
final class AgentService {
  // MARK: - State
  
  var isRunning: Bool = false
  var config: AgentConfig {
    didSet { saveConfig() }
  }
  var ledger: ActivityLedger {
    didSet { saveLedger() }
  }
  var seenItems: SeenItems {
    didSet { saveSeenItems() }
  }
  var actionLog: [AgentAction] = [] {
    didSet { saveActionLog() }
  }
  var lastMonitorTime: Date?
  var statusMessage: String = "Idle"
  
  // MARK: - Dependencies
  
  private weak var appState: AppState?
  private var monitorTask: Task<Void, Never>?
  
  // MARK: - Storage Keys
  
  private let configKey = "agent_config"
  private let ledgerKey = "agent_ledger"
  private let seenKey = "agent_seen_items"
  private let actionLogKey = "agent_action_log"
  
  // MARK: - Init
  
  init(appState: AppState? = nil) {
    self.appState = appState
    
    // Load persisted state
    if let data = UserDefaults.standard.data(forKey: configKey),
       let loaded = try? JSONDecoder().decode(AgentConfig.self, from: data) {
      self.config = loaded
    } else {
      self.config = AgentConfig()
    }
    
    if let data = UserDefaults.standard.data(forKey: ledgerKey),
       let loaded = try? JSONDecoder().decode(ActivityLedger.self, from: data) {
      self.ledger = loaded
    } else {
      self.ledger = ActivityLedger()
    }
    
    if let data = UserDefaults.standard.data(forKey: seenKey),
       let loaded = try? JSONDecoder().decode(SeenItems.self, from: data) {
      self.seenItems = loaded
    } else {
      self.seenItems = SeenItems()
    }
    
    if let data = UserDefaults.standard.data(forKey: actionLogKey),
       let loaded = try? JSONDecoder().decode([AgentAction].self, from: data) {
      self.actionLog = Array(loaded.prefix(100))  // Keep last 100
    }
    
    // Prune old ledger entries
    ledger.pruneOld()
  }
  
  func setAppState(_ appState: AppState) {
    self.appState = appState
  }
  
  // MARK: - Persistence
  
  private func saveConfig() {
    if let data = try? JSONEncoder().encode(config) {
      UserDefaults.standard.set(data, forKey: configKey)
    }
  }
  
  private func saveLedger() {
    if let data = try? JSONEncoder().encode(ledger) {
      UserDefaults.standard.set(data, forKey: ledgerKey)
    }
  }
  
  private func saveSeenItems() {
    if let data = try? JSONEncoder().encode(seenItems) {
      UserDefaults.standard.set(data, forKey: seenKey)
    }
  }
  
  private func saveActionLog() {
    let toSave = Array(actionLog.prefix(100))
    if let data = try? JSONEncoder().encode(toSave) {
      UserDefaults.standard.set(data, forKey: actionLogKey)
    }
  }
  
  // MARK: - Start/Stop
  
  func start() {
    guard !isRunning else { return }
    guard config.enabled else {
      statusMessage = "Agent disabled in settings"
      return
    }
    
    isRunning = true
    statusMessage = "Starting..."
    
    monitorTask = Task { [weak self] in
      await self?.runMonitorLoop()
    }
    
    log(action: AgentAction(
      type: .monitoring,
      targetId: "system",
      targetTitle: "Agent Started",
      detail: "Monitoring every \(config.monitorIntervalMinutes) minutes",
      success: true
    ))
  }
  
  func stop() {
    monitorTask?.cancel()
    monitorTask = nil
    isRunning = false
    statusMessage = "Stopped"
    
    log(action: AgentAction(
      type: .monitoring,
      targetId: "system",
      targetTitle: "Agent Stopped",
      detail: "Manual stop",
      success: true
    ))
  }
  
  // MARK: - Monitor Loop
  
  private func runMonitorLoop() async {
    while !Task.isCancelled {
      statusMessage = "Monitoring..."
      await performMonitorCycle()
      
      let interval = TimeInterval(config.monitorIntervalMinutes * 60)
      statusMessage = "Sleeping \(config.monitorIntervalMinutes)m..."
      
      do {
        try await Task.sleep(for: .seconds(interval))
      } catch {
        break  // Cancelled
      }
    }
  }
  
  // MARK: - Monitor Cycle
  
  func performMonitorCycle() async {
    guard let appState, let apiKey = KeychainService.getAPIKey() else {
      statusMessage = "No API key"
      return
    }
    
    ledger.pruneOld()
    lastMonitorTime = Date()
    
    // 1. Fetch new posts
    do {
      statusMessage = "Fetching posts..."
      let response = try await ShipyardClient.shared.getPosts(
        offset: 0,
        limit: 25,
        sort: "new",
        apiKey: apiKey
      )
      
      for post in response.posts {
        if !seenItems.hasSeen(postId: post.id) {
          seenItems.markSeen(postId: post.id)
          await evaluatePost(post, apiKey: apiKey)
        }
      }
    } catch {
      statusMessage = "Error fetching posts: \(error.localizedDescription)"
    }
    
    // 2. Fetch pending ships for attestation
    if config.autoAttest {
      do {
        statusMessage = "Fetching ships..."
        let response = try await ShipyardClient.shared.getShips(status: .pending, apiKey: apiKey)
        
        for ship in response.ships {
          if !seenItems.hasSeen(shipId: ship.id) && !appState.isOwnShip(ship) && !appState.hasAttested(ship.id) {
            seenItems.markSeen(shipId: ship.id)
            await evaluateShip(ship, apiKey: apiKey)
          }
        }
      } catch {
        statusMessage = "Error fetching ships: \(error.localizedDescription)"
      }
    }
    
    // 3. Maybe create a ship (if enabled and under limits)
    if config.autoCreateShips && ledger.canCreateShip() {
      await maybeCreateShip(apiKey: apiKey)
    }
    
    statusMessage = "Cycle complete"
  }
  
  // MARK: - Post Evaluation
  
  private func evaluatePost(_ post: Post, apiKey: String) async {
    // Simple heuristics for now (can add LLM later)
    guard config.autoComment && ledger.canComment() else { return }
    
    // Skip posts from self
    if let appState, post.agentId == appState.currentAgent?.id { return }
    
    // Simple engagement criteria based on aggressiveness
    let shouldEngage: Bool
    switch config.aggressiveness {
    case .conservative:
      // Only engage with show-and-tell posts with keywords
      shouldEngage = post.community == "show-and-tell" &&
        (post.title.lowercased().contains("ship") || post.title.lowercased().contains("game"))
    case .moderate:
      // Engage with most show-and-tell and agent-dev posts
      shouldEngage = post.community == "show-and-tell" || post.community == "agent-dev"
    case .aggressive:
      // Engage with most posts except bugs/requests
      shouldEngage = post.community != "bugs" && post.community != "requests"
    }
    
    guard shouldEngage else { return }
    
    // Generate a comment (simple templates for now, can add LLM later)
    let comment = generateComment(for: post)
    guard !comment.isEmpty else { return }
    
    do {
      _ = try await ShipyardClient.shared.createComment(
        postId: post.id,
        content: comment,
        apiKey: apiKey
      )
      ledger.recordComment()
      log(action: AgentAction(
        type: .comment,
        targetId: post.id,
        targetTitle: post.title,
        detail: comment,
        success: true
      ))
    } catch {
      log(action: AgentAction(
        type: .comment,
        targetId: post.id,
        targetTitle: post.title,
        detail: "Failed: \(error.localizedDescription)",
        success: false
      ))
    }
  }
  
  private func generateComment(for post: Post) -> String {
    // Simple template-based comments for now
    // TODO: Replace with LLM-generated comments
    let templates = [
      "Nice work! 🚢",
      "This is really cool, thanks for sharing!",
      "Interesting approach! Looking forward to seeing more.",
      "Great ship! The Shipyard community appreciates builders like you.",
      "Solid work! Keep shipping! 🎉",
    ]
    
    // Only comment sometimes to avoid being too spammy
    if Int.random(in: 0..<3) != 0 { return "" }
    
    return templates.randomElement() ?? ""
  }
  
  // MARK: - Ship Evaluation
  
  private func evaluateShip(_ ship: Ship, apiKey: String) async {
    guard config.autoAttest && ledger.canAttest() else { return }
    
    // Simple quality heuristics
    let meetsQuality: Bool
    switch config.aggressiveness {
    case .conservative:
      // Only attest ships with good descriptions and proof URLs
      meetsQuality = (ship.description?.count ?? 0) > 20 &&
        ship.proofUrl != nil &&
        (ship.proofUrl?.contains("github.io") == true || ship.proofUrl?.contains("shipyard.bot") == true)
    case .moderate:
      // Attest ships with any proof URL
      meetsQuality = ship.proofUrl != nil && !ship.proofUrl!.isEmpty
    case .aggressive:
      // Attest most ships
      meetsQuality = true
    }
    
    guard meetsQuality else { return }
    
    // Verify the proof URL actually works (basic check)
    if let urlString = ship.proofUrl, let url = URL(string: urlString) {
      do {
        let (_, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
          return  // Skip ships with broken proof URLs
        }
      } catch {
        return  // Skip ships we can't verify
      }
    }
    
    // Attest as valid
    do {
      _ = try await ShipyardClient.shared.attestShip(
        shipId: ship.id,
        verdict: "valid",
        apiKey: apiKey
      )
      ledger.recordAttestation()
      log(action: AgentAction(
        type: .attestation,
        targetId: ship.id,
        targetTitle: ship.title,
        detail: "Attested as valid",
        success: true
      ))
    } catch {
      log(action: AgentAction(
        type: .attestation,
        targetId: ship.id,
        targetTitle: ship.title,
        detail: "Failed: \(error.localizedDescription)",
        success: false
      ))
    }
  }
  
  // MARK: - Ship Creation
  
  private func maybeCreateShip(apiKey: String) async {
    // Placeholder for autonomous ship creation
    // This would involve:
    // 1. LLM generating an idea
    // 2. LLM generating HTML/CSS/JS code
    // 3. Writing files to the microtools directory
    // 4. Git commit and push
    // 5. Submitting to Shipyard
    
    // For now, log that we would create a ship
    statusMessage = "Ship creation not yet implemented"
  }
  
  // MARK: - Manual Triggers
  
  /// Manually trigger a monitoring cycle
  func triggerManualCycle() async {
    guard !isRunning else {
      await performMonitorCycle()
      return
    }
    
    statusMessage = "Running manual cycle..."
    await performMonitorCycle()
    statusMessage = "Manual cycle complete"
  }
  
  /// Manually attest a specific ship
  func manualAttest(shipId: String) async -> Bool {
    guard let apiKey = KeychainService.getAPIKey() else { return false }
    guard ledger.canAttest() else {
      statusMessage = "Rate limit: can't attest right now"
      return false
    }
    
    do {
      _ = try await ShipyardClient.shared.attestShip(
        shipId: shipId,
        verdict: "valid",
        apiKey: apiKey
      )
      ledger.recordAttestation()
      log(action: AgentAction(
        type: .attestation,
        targetId: shipId,
        targetTitle: "Manual attestation",
        detail: "Attested as valid",
        success: true
      ))
      return true
    } catch {
      log(action: AgentAction(
        type: .attestation,
        targetId: shipId,
        targetTitle: "Manual attestation",
        detail: "Failed: \(error.localizedDescription)",
        success: false
      ))
      return false
    }
  }
  
  // MARK: - Logging
  
  private func log(action: AgentAction) {
    actionLog.insert(action, at: 0)
    if actionLog.count > 100 {
      actionLog = Array(actionLog.prefix(100))
    }
  }
  
  // MARK: - Rate Limit Info
  
  var postsRemaining: Int {
    let oneHourAgo = Date().addingTimeInterval(-3600)
    let used = ledger.posts.filter { $0 > oneHourAgo }.count
    return max(0, 5 - used)
  }
  
  var commentsRemaining: Int {
    let oneHourAgo = Date().addingTimeInterval(-3600)
    let used = ledger.comments.filter { $0 > oneHourAgo }.count
    return max(0, 10 - used)
  }
  
  var attestationsRemaining: Int {
    let oneHourAgo = Date().addingTimeInterval(-3600)
    let used = ledger.attestations.filter { $0 > oneHourAgo }.count
    return max(0, 20 - used)
  }
  
  var shipsRemainingToday: Int {
    let oneDayAgo = Date().addingTimeInterval(-86400)
    let used = ledger.shipCreations.filter { $0 > oneDayAgo }.count
    return max(0, 3 - used)
  }
}
