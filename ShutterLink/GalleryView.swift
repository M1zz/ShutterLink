import AVKit
import SwiftUI

/// Shots taken with ShutterLink. Bursts are grouped by their best frame; share sends files via AirDrop etc.
struct GalleryView: View {
    @ObservedObject var store: ShotStore
    @Environment(\.dismiss) private var dismiss
    @State private var filter: Filter = .all
    @State private var selecting = false
    @State private var selection = Set<UUID>()
    @State private var confirmDelete = false
    @State private var viewing: Shot?

    enum Filter: CaseIterable, Identifiable {
        case all
        case best
        case videos

        var id: Self { self }
        var title: String {
            switch self {
            case .all: return String(localized: "All")
            case .best: return String(localized: "Best shots")
            case .videos: return String(localized: "Videos")
            }
        }
    }

    private var visible: [Shot] {
        switch filter {
        case .all: return store.shots
        case .best: return store.shots.filter(\.isBest)
        case .videos: return store.shots.filter { $0.kind == .video }
        }
    }

    private let columns = [GridItem(.adaptive(minimum: 110), spacing: 2)]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding()

                if visible.isEmpty {
                    ContentUnavailableView("No shots yet",
                                           systemImage: "photo.on.rectangle.angled",
                                           description: Text("Photos and videos you take with ShutterLink appear here."))
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(visible) { shot in
                                cell(for: shot)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Gallery")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbar }
            .sheet(item: $viewing) { shot in
                ShotDetailView(store: store, shot: shot)
            }
            .confirmationDialog("Delete selected shots?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    store.delete(selection)
                    selection.removeAll()
                    selecting = false
                }
            } message: {
                Text("They stay in your Photos library if they were saved there.")
            }
        }
        .preferredColorScheme(.dark)
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Close") { dismiss() }
        }
        ToolbarItem(placement: .primaryAction) {
            Button(selecting ? "Cancel" : "Select") {
                selecting.toggle()
                selection.removeAll()
            }
            .disabled(store.shots.isEmpty)
        }
        if selecting {
            ToolbarItemGroup(placement: .bottomBar) {
                ShareLink(items: selectedURLs) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .disabled(selection.isEmpty)
                Spacer()
                Text("\(selection.count) selected")
                    .font(.body)
                Spacer()
                Button(role: .destructive) {
                    confirmDelete = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
                .disabled(selection.isEmpty)
            }
        }
    }

    private var selectedURLs: [URL] {
        store.shots.filter { selection.contains($0.id) }.map(store.fileURL(for:))
    }

    private func cell(for shot: Shot) -> some View {
        Button {
            if selecting {
                if selection.contains(shot.id) { selection.remove(shot.id) } else { selection.insert(shot.id) }
            } else {
                viewing = shot
            }
        } label: {
            Color.white.opacity(0.08)
                .aspectRatio(1, contentMode: .fit)
                .overlay {
                    if let image = UIImage(contentsOfFile: store.thumbnailURL(for: shot).path) {
                        Image(uiImage: image).resizable().scaledToFill()
                    }
                }
                .clipped()
                .overlay(alignment: .topLeading) {
                    if shot.isBest {
                        Image(systemName: "star.fill")
                            .font(.body)
                            .foregroundStyle(.yellow)
                            .padding(6)
                            .shadow(radius: 2)
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    if shot.kind == .video {
                        Image(systemName: "video.fill")
                            .font(.body)
                            .foregroundStyle(.white)
                            .padding(6)
                            .shadow(radius: 2)
                    }
                }
                .overlay(alignment: .topTrailing) {
                    if selecting {
                        Image(systemName: selection.contains(shot.id) ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selection.contains(shot.id) ? Color.yellow : Color.white)
                            .padding(6)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(shot.kind == .video ? String(localized: "Video") : String(localized: "Photo"))
        .accessibilityValue(shot.isBest ? String(localized: "Best shot") : "")
    }
}

private struct ShotDetailView: View {
    @ObservedObject var store: ShotStore
    let shot: Shot
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Group {
                    switch shot.kind {
                    case .photo:
                        if let image = UIImage(contentsOfFile: store.fileURL(for: shot).path) {
                            Image(uiImage: image).resizable().scaledToFit()
                        }
                    case .video:
                        VideoPlayer(player: AVPlayer(url: store.fileURL(for: shot)))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if let burstID = shot.burstID {
                    burstStrip(burstID)
                }

                Text(shot.date.formatted(date: .abbreviated, time: .standard))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: store.fileURL(for: shot)) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    /// Other frames from the same group shot; tap one to make it the best.
    private func burstStrip(_ burstID: UUID) -> some View {
        VStack(spacing: 8) {
            Text("Group shot · tap a frame to mark it best")
                .font(.body)
                .foregroundStyle(.secondary)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(store.shots(inBurst: burstID).reversed()) { frame in
                        Button {
                            store.markBest(frame.id, inBurst: burstID)
                        } label: {
                            ZStack(alignment: .topLeading) {
                                if let image = UIImage(contentsOfFile: store.thumbnailURL(for: frame).path) {
                                    Image(uiImage: image).resizable().scaledToFill()
                                        .frame(width: 64, height: 64).clipped()
                                }
                                if frame.isBest {
                                    Image(systemName: "star.fill").font(.body).foregroundStyle(.yellow).padding(4)
                                }
                            }
                            .overlay(RoundedRectangle(cornerRadius: 6)
                                .stroke(frame.id == shot.id ? Color.white : Color.clear, lineWidth: 2))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}
