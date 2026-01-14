import SwiftUI

/// File tree sidebar view.
/// Displays repository files with lazy loading and virtualization.
struct FileTreeView: View {
    @Bindable var viewModel: FileTreeViewModel
    let onFileSelected: (FileNode) -> Void

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.rootNodes.isEmpty {
                loadingView
            } else if let error = viewModel.errorMessage {
                errorView(error)
            } else if viewModel.rootNodes.isEmpty {
                emptyView
            } else {
                fileTreeList
            }
        }
        .task {
            if viewModel.rootNodes.isEmpty {
                await viewModel.loadRootLevel()
            }
        }
    }

    // MARK: - Tree List

    private var fileTreeList: some View {
        List(selection: Binding(
            get: { viewModel.selectedNode?.id },
            set: { id in
                if let node = findNode(by: id) {
                    viewModel.selectNode(node)
                    if !node.isDirectory {
                        onFileSelected(node)
                    }
                }
            }
        )) {
            ForEach(viewModel.rootNodes) { node in
                FileTreeNodeView(
                    nodeID: node.id,
                    viewModel: viewModel,
                    onFileSelected: onFileSelected
                )
            }
        }
        .listStyle(.sidebar)
        .refreshable {
            await viewModel.refresh()
        }
    }

    // MARK: - State Views

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading files...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundStyle(.red)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Retry") {
                Task {
                    await viewModel.refresh()
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "folder")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No files found")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func findNode(by id: UUID?) -> FileNode? {
        guard let id = id else { return nil }
        // Reuse ViewModel's findNode method to avoid code duplication
        return viewModel.findNode(by: id)
    }
}

/// Individual file tree node view with expansion support.
/// Uses nodeID instead of node value to ensure we always get the latest data from ViewModel.
struct FileTreeNodeView: View {
    let nodeID: UUID
    @Bindable var viewModel: FileTreeViewModel
    let onFileSelected: (FileNode) -> Void

    /// Get the latest node data from ViewModel.
    /// This ensures we see updated children after lazy loading.
    private var node: FileNode? {
        viewModel.findNode(by: nodeID)
    }

    var body: some View {
        if let node = node {
            if node.isDirectory {
                directoryView(node)
            } else {
                fileView(node)
            }
        }
    }

    private func directoryView(_ node: FileNode) -> some View {
        DisclosureGroup(
            isExpanded: Binding(
                get: { viewModel.isExpanded(node) },
                set: { _ in
                    Task {
                        await viewModel.toggleExpansion(node)
                    }
                }
            )
        ) {
            // Use treeVersion to ensure we re-render when tree updates
            let _ = viewModel.treeVersion
            // Re-fetch node inside closure to get latest children after loading
            if let currentNode = viewModel.findNode(by: nodeID) {
                // Show error state if loading failed
                if viewModel.hasLoadError(currentNode) {
                    loadErrorView(for: currentNode)
                } else if let children = currentNode.children, !children.isEmpty {
                    ForEach(children) { child in
                        FileTreeNodeView(
                            nodeID: child.id,
                            viewModel: viewModel,
                            onFileSelected: onFileSelected
                        )
                    }
                }
            }
        } label: {
            nodeLabel(node)
        }
    }
    
    /// Error view when directory loading fails
    private func loadErrorView(for node: FileNode) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.orange)
            Text("Failed to load")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Retry") {
                Task {
                    await viewModel.retryLoadChildren(for: node)
                }
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .controlSize(.small)
        }
        .padding(.vertical, 4)
    }

    private func fileView(_ node: FileNode) -> some View {
        nodeLabel(node)
            .onTapGesture {
                viewModel.selectNode(node)
                onFileSelected(node)
            }
    }

    private func nodeLabel(_ node: FileNode) -> some View {
        HStack(spacing: 6) {
            Image(systemName: node.iconName(isExpanded: viewModel.isExpanded(node)))
                .font(.caption)
                .foregroundStyle(iconColor(node))
                .frame(width: 16)

            Text(node.name)
                .font(.callout)
                .foregroundStyle(textColor(node))
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.vertical, 2)
    }

    private func iconColor(_ node: FileNode) -> Color {
        if node.isGitIgnored {
            return .secondary.opacity(0.6)
        }
        if node.isDirectory {
            return .blue
        }
        return .secondary
    }

    private func textColor(_ node: FileNode) -> Color {
        node.isGitIgnored ? .secondary : .primary
    }
}

// MARK: - Preview

#Preview {
    struct PreviewWrapper: View {
        @State private var viewModel: FileTreeViewModel

        init() {
            let repo = Repository(url: URL(fileURLWithPath: NSHomeDirectory()))
            _viewModel = State(initialValue: FileTreeViewModel(repository: repo))
        }

        var body: some View {
            FileTreeView(viewModel: viewModel) { node in
                print("Selected: \(node.name)")
            }
            .frame(width: 250, height: 400)
        }
    }
    return PreviewWrapper()
}
