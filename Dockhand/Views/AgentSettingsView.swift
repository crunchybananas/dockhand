//
//  AgentSettingsView.swift
//  Dockhand
//
//  Created by Cory Loken on 2/2/26.
//
//  UI for configuring and monitoring the autonomous agent
//

import SwiftUI

struct AgentSettingsView: View {
  @Bindable var agentService: AgentService
  @State private var showingActionLog = false
  @State private var llmApiKey = ""
  @State private var isGeneratingShip = false
  
  private let llmService = LLMService()
  
  var body: some View {
    Form {
      // MARK: - Status Section
      Section {
        HStack {
          Circle()
            .fill(agentService.isRunning ? Color.green : Color.gray)
            .frame(width: 10, height: 10)
          Text(agentService.isRunning ? "Running" : "Stopped")
            .font(.headline)
          Spacer()
          Text(agentService.statusMessage)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        
        if let lastTime = agentService.lastMonitorTime {
          LabeledContent("Last Check") {
            Text(lastTime, style: .relative)
              .foregroundStyle(.secondary)
          }
        }
        
        HStack {
          Button(agentService.isRunning ? "Stop Agent" : "Start Agent") {
            if agentService.isRunning {
              agentService.stop()
            } else {
              agentService.start()
            }
          }
          .buttonStyle(.borderedProminent)
          .tint(agentService.isRunning ? .red : .green)
          
          Button("Run Now") {
            Task {
              await agentService.triggerManualCycle()
            }
          }
          .buttonStyle(.bordered)
        }
      } header: {
        Text("Agent Status")
      }
      
      // MARK: - Rate Limits Section
      Section {
        RateLimitRow(label: "Posts", remaining: agentService.postsRemaining, max: 5, period: "hour")
        RateLimitRow(label: "Comments", remaining: agentService.commentsRemaining, max: 10, period: "hour")
        RateLimitRow(label: "Attestations", remaining: agentService.attestationsRemaining, max: 20, period: "hour")
        RateLimitRow(label: "Ship Creations", remaining: agentService.shipsRemainingToday, max: 3, period: "day")
      } header: {
        Text("Rate Limits (Karma Protection)")
      } footer: {
        Text("Exceeding these limits can result in a 90% karma penalty on Shipyard.")
      }
      
      // MARK: - Configuration Section
      Section {
        Toggle("Enable Agent", isOn: $agentService.config.enabled)
        
        Picker("Aggressiveness", selection: $agentService.config.aggressiveness) {
          ForEach(AgentConfig.Aggressiveness.allCases, id: \.self) { level in
            Text(level.rawValue.capitalized).tag(level)
          }
        }
        
        Stepper(
          "Check every \(agentService.config.monitorIntervalMinutes) minutes",
          value: $agentService.config.monitorIntervalMinutes,
          in: 5...60,
          step: 5
        )
      } header: {
        Text("Configuration")
      }
      
      // MARK: - Features Section
      Section {
        Toggle("Auto-Attest Ships", isOn: $agentService.config.autoAttest)
        Toggle("Auto-Comment on Posts", isOn: $agentService.config.autoComment)
        Toggle("Auto-Create Ships", isOn: $agentService.config.autoCreateShips)
        
        Button("Generate Ship Now") {
          Task {
            isGeneratingShip = true
            _ = await agentService.generateShipNow()
            isGeneratingShip = false
          }
        }
        .buttonStyle(.bordered)
        .disabled(isGeneratingShip || !llmService.hasAPIKey)
      } header: {
        Text("Autonomous Features")
      } footer: {
        Text("Auto-Create Ships will use AI to generate new microtools. Requires LLM API key.")
      }
      
      // MARK: - LLM Settings Section
      Section {
        Picker("Provider", selection: $agentService.config.llmProvider) {
          Text("OpenAI").tag("openai")
          Text("Anthropic").tag("anthropic")
        }
        
        TextField("Model", text: $agentService.config.llmModel)
          .textFieldStyle(.roundedBorder)
        
        HStack {
          if llmService.hasAPIKey {
            Text("API Key configured ✓")
              .foregroundStyle(.green)
            Spacer()
            Button("Remove") {
              try? llmService.deleteAPIKey()
            }
            .buttonStyle(.bordered)
            .tint(.red)
          } else {
            SecureField("API Key", text: $llmApiKey)
              .textFieldStyle(.roundedBorder)
            Button("Save") {
              guard !llmApiKey.isEmpty else { return }
              try? llmService.setAPIKey(llmApiKey)
              llmApiKey = ""
            }
            .buttonStyle(.borderedProminent)
            .disabled(llmApiKey.isEmpty)
          }
        }
        
        if !llmService.hasAPIKey {
          Text("Enter your \(agentService.config.llmProvider == "openai" ? "OpenAI" : "Anthropic") API key to enable LLM features")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      } header: {
        Text("LLM Configuration")
      }
      
      // MARK: - Action Log Section
      Section {
        Button {
          showingActionLog = true
        } label: {
          HStack {
            Text("View Action Log")
            Spacer()
            Text("\(agentService.actionLog.count) actions")
              .foregroundStyle(.secondary)
            Image(systemName: "chevron.right")
              .foregroundStyle(.secondary)
          }
        }
        .buttonStyle(.plain)
        
        if let lastAction = agentService.actionLog.first {
          VStack(alignment: .leading, spacing: 4) {
            Text("Last Action")
              .font(.caption)
              .foregroundStyle(.secondary)
            HStack {
              Image(systemName: iconForAction(lastAction.type))
                .foregroundStyle(lastAction.success ? .green : .red)
              Text(lastAction.targetTitle)
                .lineLimit(1)
              Spacer()
              Text(lastAction.timestamp, style: .relative)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
        }
      } header: {
        Text("Activity")
      }
    }
    .formStyle(.grouped)
    .navigationTitle("Autonomous Agent")
    .sheet(isPresented: $showingActionLog) {
      ActionLogView(actions: agentService.actionLog)
    }
  }
  
  private func iconForAction(_ type: AgentAction.ActionType) -> String {
    switch type {
    case .attestation: return "checkmark.seal"
    case .comment: return "text.bubble"
    case .post: return "square.and.pencil"
    case .shipCreation: return "ferry"
    case .monitoring: return "binoculars"
    }
  }
}

// MARK: - Rate Limit Row

struct RateLimitRow: View {
  let label: String
  let remaining: Int
  let max: Int
  let period: String
  
  var body: some View {
    HStack {
      Text(label)
      Spacer()
      Text("\(remaining)/\(max)")
        .foregroundStyle(remaining == 0 ? .red : (remaining <= 2 ? .orange : .secondary))
      Text("per \(period)")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
  }
}

// MARK: - Action Log View

struct ActionLogView: View {
  let actions: [AgentAction]
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationStack {
      List(actions) { action in
        VStack(alignment: .leading, spacing: 4) {
          HStack {
            Image(systemName: iconForAction(action.type))
              .foregroundStyle(action.success ? .green : .red)
            Text(action.targetTitle)
              .font(.headline)
              .lineLimit(1)
            Spacer()
            Text(action.timestamp, style: .relative)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          
          Text(action.detail)
            .font(.caption)
            .foregroundStyle(.secondary)
            .lineLimit(2)
          
          HStack {
            Text(action.type.rawValue.capitalized)
              .font(.caption2)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.secondary.opacity(0.2))
              .cornerRadius(4)
            
            Text("ID: \(action.targetId)")
              .font(.caption2)
              .foregroundStyle(.tertiary)
          }
        }
        .padding(.vertical, 4)
      }
      .navigationTitle("Action Log")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Done") { dismiss() }
        }
      }
    }
  }
  
  private func iconForAction(_ type: AgentAction.ActionType) -> String {
    switch type {
    case .attestation: return "checkmark.seal"
    case .comment: return "text.bubble"
    case .post: return "square.and.pencil"
    case .shipCreation: return "ferry"
    case .monitoring: return "binoculars"
    }
  }
}

#Preview {
  AgentSettingsView(agentService: AgentService())
}
