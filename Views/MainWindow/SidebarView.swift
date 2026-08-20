//
//  SidebarView.swift
//  jez-blog
//
//  Sidebar with collections and tags
//

import SwiftUI

struct SidebarView: View {
    @Binding var selectedCollection: CollectionType
    @Binding var selectedTag: String?
    let allTags: [String]
    let onCreatePost: (PostDisplayType) -> Void
    
    @State private var isTagsExpanded: Bool = true
    
    var body: some View {
        List(selection: $selectedCollection) {
            Section {
                Menu {
                    Button("Thread") {
                        onCreatePost(.thread)
                    }
                    Button("Media Arrangement") {
                        onCreatePost(.mediaArrangement)
                    }
                    Button("Short + Image") {
                        onCreatePost(.shortWithImage)
                    }
                    Button("Video Clip") {
                        onCreatePost(.videoClip)
                    }
                    Button("Link Card") {
                        onCreatePost(.linkCard)
                    }
                } label: {
                    Label("New Post", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.plain)
                .padding(.vertical, 4)
            }
            
            Section("Collections") {
                ForEach(CollectionType.allCases, id: \.self) { collection in
                    NavigationLink(value: collection) {
                        Label(collection.rawValue, systemImage: iconForCollection(collection))
                    }
                }
            }
            
            Section("Tags") {
                DisclosureGroup(isExpanded: $isTagsExpanded) {
                    if allTags.isEmpty {
                        Text("No tags yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(.leading, 20)
                    } else {
                        ForEach(allTags, id: \.self) { tag in
                            Button {
                                if selectedTag == tag {
                                    selectedTag = nil
                                } else {
                                    selectedTag = tag
                                }
                            } label: {
                                HStack {
                                    Text("#\(tag)")
                                        .font(.body)
                                    Spacer()
                                    if selectedTag == tag {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.accentColor)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                } label: {
                    Label("Tags", systemImage: "tag")
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("jez-blog")
        .background(.ultraThinMaterial)
    }
    
    private func iconForCollection(_ collection: CollectionType) -> String {
        switch collection {
        case .all: return "square.grid.2x2"
        case .threads: return "text.alignleft"
        case .media: return "photo.on.rectangle"
        case .links: return "link"
        case .unpublished: return "eye.slash"
        }
    }
}
