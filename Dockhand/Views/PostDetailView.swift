//
//  PostDetailView.swift
//  Dockhand
//
//  Post detail with comments
//

import SwiftUI

struct PostDetailView: View {
    @Environment(AppState.self) private var appState
    
    let postId: String
    
    @State private var post: Post?
    @State private var comments: [Comment] = []
    @State private var isLoading: Bool = false
    @State private var commentText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            if let post {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Post Header
                        VStack(alignment: .leading, spacing: 6) {
                            Text(post.title)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            HStack {
                                Text(post.agentName ?? "Unknown")
                                    .foregroundStyle(.secondary)
                                
                                if let createdAt = post.createdAt {
                                    Text("• \(createdAt, format: .relative(presentation: .numeric))")
                                        .foregroundStyle(.secondary)
                                }
                                
                                if let community = post.community {
                                    Text("• c/\(community)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .font(.caption)
                        }
                        
                        if let content = post.content, !content.isEmpty {
                            Text(content)
                                .textSelection(.enabled)
                        }
                        
                        Divider()
                        
                        // Comments
                        Text("Comments (\(comments.count))")
                            .font(.headline)
                        
                        if comments.isEmpty {
                            Text("No comments yet")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(threadedComments, id: \.id) { node in
                                CommentThreadView(node: node)
                            }
                        }
                    }
                    .padding()
                }
            } else if isLoading {
                ProgressView("Loading post...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView("Post not found", systemImage: "exclamationmark.triangle")
            }
            
            Divider()
            
            // Comment composer
            HStack {
                TextField("Write a comment...", text: $commentText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                
                Button("Send") {
                    sendComment()
                }
                .buttonStyle(.borderedProminent)
                .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .navigationTitle("Post")
        .task {
            await load()
        }
    }
    
    private func load() async {
        isLoading = true
        defer { isLoading = false }
        if let response = await appState.loadPostDetail(postId: postId) {
            post = response.post
            comments = response.comments
        }
    }
    
    private func sendComment() {
        let trimmed = commentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Task {
            if let newComment = await appState.createComment(postId: postId, content: trimmed) {
                comments.append(newComment)
                commentText = ""
            }
        }
    }
    
    private var threadedComments: [CommentNode] {
        let grouped = Dictionary(grouping: comments) { $0.parentId }
        func buildNodes(parentId: String?) -> [CommentNode] {
            let items = grouped[parentId] ?? []
            return items.map { CommentNode(comment: $0, replies: buildNodes(parentId: $0.id)) }
        }
        return buildNodes(parentId: nil)
    }
}

struct CommentNode: Identifiable {
    let id: String
    let comment: Comment
    let replies: [CommentNode]
    
    init(comment: Comment, replies: [CommentNode]) {
        self.id = comment.id
        self.comment = comment
        self.replies = replies
    }
}

struct CommentThreadView: View {
    let node: CommentNode
    var indent: Int = 0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CommentRowView(comment: node.comment)
                .padding(.leading, CGFloat(indent) * 16)
            ForEach(node.replies) { reply in
                CommentThreadView(node: reply, indent: indent + 1)
            }
        }
    }
}

struct CommentRowView: View {
    let comment: Comment
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(comment.authorName ?? "Unknown")
                    .fontWeight(.semibold)
                
                if let createdAt = comment.createdAt {
                    Text("• \(createdAt, format: .relative(presentation: .numeric))")
                        .foregroundStyle(.secondary)
                }
            }
            .font(.caption)
            
            Text(comment.content)
                .textSelection(.enabled)
        }
        .padding(10)
        .background(.quaternary.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    PostDetailView(postId: "1")
        .environment(AppState())
}
