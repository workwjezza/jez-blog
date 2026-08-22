//
//  SidebarView.swift
//  jez-blog
//

import SwiftUI

struct SidebarView: View {
    @Binding var selectedCollection: PostCollection
    @Binding var selectedTag: String?
    @Binding var selectedFolder: Folder?
    @Binding var searchText: String

    let tags: [String]
    let onNewPost: (PostDisplayType) -> Void

    @State private var tagsExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search at top
            searchField
                .padding(.horizontal, 12)
                .padding(.top, 12)
                .padding(.bottom, 8)

            List {
                // Collections section - no counts shown
                Section("Collections") {
                    ForEach(PostCollection.allCases) { collection in
                        collectionRow(collection)
                    }
                }

                // Folders section
                FolderSectionView(
                    selectedFolder: $selectedFolder,
                    selectedCollection: selectedCollection,
                    selectedTag: selectedTag
                )

                // Tags section
                if !tags.isEmpty {
                    Section {
                        DisclosureGroup(isExpanded: $tagsExpanded) {
                            ForEach(tags, id: \.self) { tag in
                                tagRow(tag)
                            }
                        } label: {
                            Label("Tags", systemImage: "number")
                                .font(.callout)
                        }
                    }
                }

                // New Post buttons at bottom
                Section {
                    newPostButtons
                        .padding(.vertical, 4)
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
        .background(.ultraThinMaterial)
    }

    // MARK: - Pieces

    /// Search field now in sidebar at top
    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.caption)

            TextField("Search posts", text: $searchText)
                .textFieldStyle(.plain)
                .font(.callout)

            if !searchText.isEmpty {
                Button {
                    withAnimation(Theme.spring) { searchText = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Theme.cardFill)
        )
    }

    /// A button per post type, moved to bottom of sidebar.
    private var newPostButtons: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New Post")
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            NewPostButtons(minimumWidth: 66, action: onNewPost)
        }
    }

    /// Collection row without count badge
    private func collectionRow(_ collection: PostCollection) -> some View {
        let isSelected = selectedCollection == collection && selectedTag == nil && selectedFolder == nil

        return Button {
            withAnimation(Theme.spring) {
                selectedCollection = collection
                selectedTag = nil
                selectedFolder = nil
            }
        } label: {
            HStack {
                Label(collection.label, systemImage: collection.symbolName)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Theme.accent.opacity(0.18) : .clear)
        )
        .foregroundStyle(isSelected ? Theme.accent : .primary)
    }

    private func tagRow(_ tag: String) -> some View {
        let isSelected = selectedTag == tag

        return Button {
            withAnimation(Theme.spring) {
                selectedTag = isSelected ? nil : tag
                if selectedTag != nil {
                    selectedCollection = .all
                    selectedFolder = nil
                }
            }
        } label: {
            HStack {
                Text("#\(tag)")
                    .font(.callout)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(isSelected ? Theme.accent.opacity(0.18) : .clear)
        )
        .foregroundStyle(isSelected ? Theme.accent : .primary)
    }
}

#Preview {
    SidebarView(
        selectedCollection: .constant(.all),
        selectedTag: .constant(nil),
        selectedFolder: .constant(nil),
        searchText: .constant(""),
        tags: ["garden", "film", "notes"],
        onNewPost: { _ in }
    )
    .frame(width: 250, height: 700)
}
