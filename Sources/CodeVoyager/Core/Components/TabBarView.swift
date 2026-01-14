import SwiftUI

/// Tab bar for managing open files.
/// Supports overflow menu for many tabs (as per PRD).
struct TabBarView: View {
    @Binding var tabs: [TabItem]
    @Binding var selectedTab: UUID?

    /// Maximum number of visible tabs before overflow
    private let maxVisibleTabs = 8

    var body: some View {
        HStack(spacing: 0) {
            // Visible tabs
            ForEach(visibleTabs) { tab in
                SingleTabView(
                    tab: tab,
                    isSelected: tab.id == selectedTab,
                    onSelect: { selectedTab = tab.id },
                    onClose: { closeTab(tab.id) }
                )
            }

            // Overflow menu
            if !overflowTabs.isEmpty {
                overflowMenu
            }

            Spacer()
        }
        .frame(height: 32)
        .background(Color(nsColor: .windowBackgroundColor))
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    private var visibleTabs: [TabItem] {
        Array(tabs.prefix(maxVisibleTabs))
    }

    private var overflowTabs: [TabItem] {
        Array(tabs.dropFirst(maxVisibleTabs))
    }

    private var overflowMenu: some View {
        Menu {
            ForEach(overflowTabs) { tab in
                Button(action: { selectedTab = tab.id }) {
                    Label(tab.title, systemImage: tab.type.iconName)
                }
            }
        } label: {
            Image(systemName: "chevron.down")
                .frame(width: 24, height: 24)
        }
        .menuStyle(.borderlessButton)
        .frame(width: 32)
    }

    private func closeTab(_ id: UUID) {
        guard let index = tabs.firstIndex(where: { $0.id == id }) else { return }
        
        tabs.remove(at: index)
        
        // Select adjacent tab if closing the currently selected tab
        if selectedTab == id {
            if !tabs.isEmpty {
                // Select the next tab, or the previous one if we closed the last tab
                let newIndex = min(index, tabs.count - 1)
                selectedTab = tabs[newIndex].id
            } else {
                selectedTab = nil
            }
        }
    }
}

/// Individual tab view.
/// Named SingleTabView to avoid conflict with SwiftUI's TabView.
struct SingleTabView: View {
    let tab: TabItem
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tab.type.iconName)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(tab.title)
                .font(.callout)
                .lineLimit(1)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .opacity(isHovering || isSelected ? 1 : 0)
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .overlay(alignment: .bottom) {
            if isSelected {
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(height: 2)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { isHovering = $0 }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State var tabs = [
            TabItem(type: .file, filePath: "/test/main.swift", title: "main.swift"),
            TabItem(type: .file, filePath: "/test/app.swift", title: "App.swift"),
            TabItem(type: .diff(commitSHA: "abc123"), title: "Diff: abc123"),
        ]
        @State var selected: UUID?

        var body: some View {
            VStack {
                TabBarView(tabs: $tabs, selectedTab: $selected)
                Spacer()
            }
            .frame(width: 600, height: 400)
            .onAppear { selected = tabs.first?.id }
        }
    }
    return PreviewWrapper()
}
