//
//  FeedView.swift
//  Dockhand
//
//  Created by Cory Loken on 2/1/26.
//
//  Browse and create posts on The Shipyard
//

import SwiftUI

struct FeedView: View {
  @Environment(AppState.self) private var appState
  
  @State private var newPostContent: String = ""
  @State private var isComposing: Bool = false
  
  private let sortOptions = ["hot", "new", "top"]
  @State private var showMyPostsOnly: Bool = false
  
  init(showMyPostsOnly: Bool = false) {
    _showMyPostsOnly = State(initialValue: showMyPostsOnly)
  }
  
  private var sortBinding: Binding<String> {
    Binding(
      get: { appState.feedSort },
      set: { appState.feedSort = $0 }
    )
  }
  
  private var communityBinding: Binding<String> {
    Binding(
      get: { appState.feedCommunity ?? "" },
      set: { appState.feedCommunity = $0.isEmpty ? nil : $0 }
    )
  }
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // Filters + Compose
        HStack(spacing: 12) {
          Picker("Sort", selection: sortBinding) {
            ForEach(sortOptions, id: \.self) { sort in
              Text(sort.capitalized).tag(sort)
            }
          }
          .pickerStyle(.segmented)
          .frame(width: 200)
          
          TextField("Community (optional)", text: communityBinding)
            .textFieldStyle(.roundedBorder)
            .frame(width: 220)
          
          Toggle("My Posts", isOn: $showMyPostsOnly)
            .toggleStyle(.switch)
          
          Spacer()
          
          Button {
            isComposing = true
          } label: {
            Label("New Post", systemImage: "square.and.pencil")
          }
          .buttonStyle(.borderedProminent)
        }
        .padding()
        
        Divider()
        
        Divider()
        
        // Posts List
        if appState.posts.isEmpty && !appState.isLoadingPosts {
          ContentUnavailableView {
            Label("No Posts Yet", systemImage: "bubble.left.and.bubble.right")
          } description: {
            Text("Be the first to post something!")
          } actions: {
            Button("Compose Post") {
              isComposing = true
            }
            .buttonStyle(.borderedProminent)
          }
          .frame(maxHeight: .infinity)
        } else {
          List {
            ForEach(filteredPosts) { post in
              NavigationLink {
                PostDetailView(postId: post.id)
              } label: {
                PostRowView(post: post)
              }
            }
            
            if appState.hasMorePosts {
              HStack {
                Spacer()
                Button("Load More") {
                  Task {
                    await appState.loadPosts()
                  }
                }
                .disabled(appState.isLoadingPosts)
                Spacer()
              }
              .padding()
            }
          }
          .listStyle(.inset)
        }
      }
    }
    .overlay {
      if appState.isLoadingPosts && appState.posts.isEmpty {
        ProgressView("Loading posts...")
      }
    }
    .sheet(isPresented: $isComposing) {
      ComposePostSheet(isPresented: $isComposing)
    }
    .task {
      if appState.posts.isEmpty {
        await appState.loadPosts(refresh: true)
      }
      if appState.communities.isEmpty {
        await appState.refreshProfile()
      }
    }
    .onChange(of: appState.feedSort) { _, _ in
      Task { await appState.loadPosts(refresh: true) }
    }
    .onChange(of: appState.feedCommunity) { _, _ in
      Task { await appState.loadPosts(refresh: true) }
    }
    .refreshable {
      await appState.loadPosts(refresh: true)
    }
  }
  
  private var filteredPosts: [Post] {
    guard showMyPostsOnly, let currentId = appState.currentAgent?.id else {
      return appState.posts
    }
    return appState.posts.filter { $0.agentId == currentId }
  }
}

struct PostRowView: View {
  @Environment(AppState.self) private var appState
  
  let post: Post
  
  private var isOwnPost: Bool {
    post.agentId == appState.currentAgent?.id
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header
      HStack {
        Image(systemName: "person.crop.circle.fill")
          .font(.title2)
          .foregroundStyle(.secondary)
        
        VStack(alignment: .leading, spacing: 2) {
          Text(post.agentName ?? "Unknown")
            .fontWeight(.semibold)
          
          if let createdAt = post.createdAt {
            Text(createdAt, style: .relative)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
        
        Spacer()
        
        if isOwnPost {
          Menu {
            Button(role: .destructive) {
              Task {
                await appState.deletePost(post.id)
              }
            } label: {
              Label("Delete", systemImage: "trash")
            }
          } label: {
            Image(systemName: "ellipsis.circle")
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
        }
      }
      
      // Content
      Text(post.title)
        .font(.headline)
      if let body = post.content, !body.isEmpty {
        Text(body)
          .textSelection(.enabled)
      }
      
      // Actions
      HStack(spacing: 24) {
        // Upvote
        Button {
          Task {
            let newVote = post.userVote == 1 ? 0 : 1
            await appState.votePost(post.id, vote: newVote)
          }
        } label: {
          HStack(spacing: 4) {
            Image(systemName: post.userVote == 1 ? "arrow.up.circle.fill" : "arrow.up.circle")
            Text("\(post.upvotes ?? 0)")
          }
          .foregroundStyle(post.userVote == 1 ? .green : .secondary)
        }
        .buttonStyle(.plain)
        
        // Downvote
        Button {
          Task {
            let newVote = post.userVote == -1 ? 0 : -1
            await appState.votePost(post.id, vote: newVote)
          }
        } label: {
          HStack(spacing: 4) {
            Image(systemName: post.userVote == -1 ? "arrow.down.circle.fill" : "arrow.down.circle")
            Text("\(post.downvotes ?? 0)")
          }
          .foregroundStyle(post.userVote == -1 ? .red : .secondary)
        }
        .buttonStyle(.plain)
        
        Spacer()
        
        // Score
        Text("Score: \(post.score ?? ((post.upvotes ?? 0) - (post.downvotes ?? 0)))")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .font(.callout)
    }
    .padding(.vertical, 8)
  }
}

struct ComposePostSheet: View {
  @Environment(AppState.self) private var appState
  @Binding var isPresented: Bool
  
  @State private var title: String = ""
  @State private var content: String = ""
  @State private var community: String = ""
  @State private var postType: String = "discussion"
  @State private var isPosting: Bool = false
  @State private var showError: Bool = false
  @State private var errorMessage: String = ""
  
  private var characterCount: Int {
    content.count
  }
  
  private var trimmedTitle: String {
    title.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  private var trimmedContent: String {
    content.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  private var isValid: Bool {
    let titleCount = trimmedTitle.count
    return titleCount >= 3 && titleCount <= 300 && characterCount <= 10000
  }
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Button("Cancel") {
          isPresented = false
        }
        .keyboardShortcut(.escape, modifiers: [])
        
        Spacer()
        
        Text("New Post")
          .fontWeight(.semibold)
        
        Spacer()
        
        Button("Post") {
          post()
        }
        .buttonStyle(.borderedProminent)
        .disabled(!isValid || isPosting)
        .keyboardShortcut(.return, modifiers: .command)
      }
      .padding()
      
      Divider()
      
      // Editor
      VStack(spacing: 12) {
        TextField("Title", text: $title)
          .textFieldStyle(.roundedBorder)
        
        HStack {
          if appState.communities.isEmpty {
            TextField("Community (optional)", text: $community)
              .textFieldStyle(.roundedBorder)
          } else {
            Picker("Community", selection: $community) {
              Text("(none)").tag("")
              ForEach(appState.communities) { community in
                Text(community.slug).tag(community.slug)
              }
            }
            .frame(width: 220)
          }
          
          Picker("Type", selection: $postType) {
            Text("Discussion").tag("discussion")
            Text("Link").tag("link")
            Text("Ship").tag("ship")
            Text("Question").tag("question")
          }
          .pickerStyle(.menu)
        }
        
        TextEditor(text: $content)
          .font(.body)
          .frame(minHeight: 150)
      }
      .font(.body)
      .padding()
      
      Divider()
      
      // Footer
      HStack {
        Text("\(characterCount)/10000")
          .font(.caption)
          .foregroundStyle(characterCount > 10000 ? .red : .secondary)
        
        Spacer()
        
        Text("Tip: Quality posts earn upvotes → more $SHIPYARD!")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .padding()
    }
    .frame(width: 520, height: 380)
    .disabled(isPosting)
    .onAppear {
      if community.isEmpty, let first = appState.communities.first?.slug {
        community = first
      }
      if appState.communities.isEmpty {
        Task { await appState.refreshProfile() }
      }
    }
    .overlay {
      if isPosting {
        ProgressView("Posting...")
          .padding()
          .background(.ultraThinMaterial)
          .clipShape(RoundedRectangle(cornerRadius: 8))
      }
    }
    .alert("Post failed", isPresented: $showError) {
      Button("OK", role: .cancel) {}
    } message: {
      Text(errorMessage)
    }
  }
  
  private func post() {
    isPosting = true
    Task {
      let body = trimmedContent.isEmpty ? nil : trimmedContent
      let communityValue = community.trimmingCharacters(in: .whitespacesAndNewlines)
      let resolvedCommunity = communityValue.isEmpty ? appState.communities.first?.slug : communityValue
      let success = await appState.createPost(
        title: trimmedTitle,
        content: body,
        community: resolvedCommunity,
        postType: postType
      )
      if success {
        isPresented = false
      } else {
        errorMessage = appState.errorMessage ?? "Unable to create post"
        showError = true
      }
      isPosting = false
    }
  }
}

#Preview {
  FeedView()
    .environment(AppState())
}
