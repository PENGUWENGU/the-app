import SwiftUI
import CoreLocation

/// Dedicated modal/sheet component that displays the list of routes saved in local storage,
/// allowing users to select, rename, export, or delete their saved paths.
public struct SavedRoutesModalView: View {
    @EnvironmentObject private var session: SpoofSession
    @Environment(\.dismiss) private var dismiss

    public var onSelectRoute: ((SavedRoute) -> Void)?

    @State private var searchText = ""
    @State private var routeToRename: SavedRoute?
    @State private var renameText = ""
    @State private var routeToDelete: SavedRoute?
    @State private var showDeleteConfirmation = false
    @State private var previewRoute: SavedRoute?

    public init(onSelectRoute: ((SavedRoute) -> Void)? = nil) {
        self.onSelectRoute = onSelectRoute
    }

    private var filteredRoutes: [SavedRoute] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return session.savedRoutes
        }
        return session.savedRoutes.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    public var body: some View {
        NavigationStack {
            Group {
                if session.savedRoutes.isEmpty {
                    emptyStateView
                } else {
                    routesListView
                }
            }
            .searchable(text: $searchText, prompt: "Search saved paths…")
            .navigationTitle("Saved Routes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
            .alert("Rename Route", isPresented: Binding(
                get: { routeToRename != nil },
                set: { if !$0 { routeToRename = nil } }
            )) {
                TextField("Route Name", text: $renameText)
                Button("Save") {
                    if let route = routeToRename {
                        session.renameSavedRoute(route, to: renameText)
                    }
                    routeToRename = nil
                }
                Button("Cancel", role: .cancel) {
                    routeToRename = nil
                }
            }
            .confirmationDialog(
                "Delete Route",
                isPresented: $showDeleteConfirmation,
                presenting: routeToDelete
            ) { route in
                Button("Delete \"\(route.name)\"", role: .destructive) {
                    session.removeSavedRoute(route)
                    routeToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    routeToDelete = nil
                }
            } message: { route in
                Text("Are you sure you want to delete this saved route? This cannot be undone.")
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.fill")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Saved Routes")
                .font(.headline)
            Text("Draw a path on the map or calculate a road route, then tap 'Save current route' to access your paths here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    private var routesListView: some View {
        List {
            ForEach(filteredRoutes) { route in
                HStack(spacing: 14) {
                    Image(systemName: "point.topleft.filled.down.to.point.bottomright.curvepath")
                        .font(.title2)
                        .foregroundStyle(LocusTheme.accent)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(route.name)
                            .font(.headline.weight(.semibold))

                        HStack(spacing: 8) {
                            Text(route.formattedDistance)
                                .font(.caption.monospaced().weight(.medium))
                                .foregroundStyle(LocusTheme.accent)

                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("\(route.waypoints.count) waypoints")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text("•")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Text(route.dateCreated, format: .dateTime.month().day())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Button {
                        onSelectRoute?(route)
                        dismiss()
                    } label: {
                        Text("Select")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(LocusTheme.accent)
                            .foregroundStyle(.black)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        routeToDelete = route
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash.fill")
                    }

                    Button {
                        routeToRename = route
                        renameText = route.name
                    } label: {
                        Label("Rename", systemImage: "pencil")
                    }
                    .tint(.orange)
                }
            }
        }
    }
}
