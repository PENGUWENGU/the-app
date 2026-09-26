import SwiftUI
import CoreLocation

/// Modal component named `RouteManagerModal` that retrieves saved routes from localStorage
/// and renders them in an interactive list with options to select, rename, or delete each entry.
public struct RouteManagerModal: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: SpoofSession

    public var onSelectRoute: ((SavedRoute) -> Void)?

    @State private var routes: [SavedRoute] = []
    @State private var searchQuery: String = ""
    @State private var routeToRename: SavedRoute?
    @State private var renameText: String = ""
    @State private var routeToDelete: SavedRoute?
    @State private var showDeleteConfirmation: Bool = false
    @State private var selectedRouteForDetails: SavedRoute? = nil

    public init(onSelectRoute: ((SavedRoute) -> Void)? = nil) {
        self.onSelectRoute = onSelectRoute
    }

    private var filteredRoutes: [SavedRoute] {
        if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return routes
        }
        return routes.filter {
            $0.name.localizedCaseInsensitiveContains(searchQuery)
        }
    }

    public var body: some View {
        NavigationStack {
            Group {
                if routes.isEmpty {
                    emptyStateView
                } else {
                    listView
                }
            }
            .searchable(text: $searchQuery, prompt: "Search saved routes…")
            .navigationTitle("Route Manager")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                reloadRoutes()
            }
            .alert("Rename Route", isPresented: Binding(
                get: { routeToRename != nil },
                set: { if !$0 { routeToRename = nil } }
            )) {
                TextField("Route Name", text: $renameText)
                Button("Save") {
                    if let route = routeToRename {
                        performRename(route: route, newName: renameText)
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
                    performDelete(route: route)
                }
                Button("Cancel", role: .cancel) {
                    routeToDelete = nil
                }
            } message: { route in
                Text("Are you sure you want to delete \"\(route.name)\"? This action cannot be undone.")
            }
            .sheet(item: $selectedRouteForDetails) { route in
                RouteDetailView(route: route, onLoadRoute: onSelectRoute)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "map.circle")
                .font(.system(size: 56))
                .foregroundStyle(LocusTheme.accent)

            Text("No Saved Routes")
                .font(.title3.weight(.bold))

            Text("Routes you save on the map or import from GPX files will be listed here for quick retrieval and management.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.ignoresSafeArea())
    }

    private var listView: some View {
        List {
            ForEach(filteredRoutes) { route in
                HStack(spacing: 12) {
                    Image(systemName: "point.topleft.filled.down.to.point.bottomright.curvepath")
                        .font(.title3)
                        .foregroundStyle(LocusTheme.accent)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(route.name)
                            .font(.headline)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            Text(route.formattedDistance)
                                .font(.caption.monospaced().weight(.semibold))
                                .foregroundStyle(LocusTheme.accent)

                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text("\(route.waypoints.count) pts")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.secondary)

                            Text(route.dateCreated, format: .dateTime.month().day())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Action buttons
                    HStack(spacing: 8) {
                        // Details & D3 Chart Button
                        Button {
                            selectedRouteForDetails = route
                        } label: {
                            Image(systemName: "chart.xyaxis.line")
                                .font(.title3)
                                .foregroundStyle(LocusTheme.accent)
                        }
                        .buttonStyle(.plain)

                        // Export GPX ShareLink
                        if let gpxUrl = route.exportToGPXFile() {
                            ShareLink(item: gpxUrl) {
                                Image(systemName: "square.and.arrow.up.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(LocusTheme.accent)
                            }
                            .buttonStyle(.plain)
                        }

                        // Rename Button
                        Button {
                            routeToRename = route
                            renameText = route.name
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.orange)
                        }
                        .buttonStyle(.plain)

                        // Delete Button
                        Button {
                            routeToDelete = route
                            showDeleteConfirmation = true
                        } label: {
                            Image(systemName: "trash.circle.fill")
                                .font(.title3)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)

                        // Select / Load Button
                        if let onSelect = onSelectRoute {
                            Button {
                                onSelect(route)
                                dismiss()
                            } label: {
                                Text("Load")
                                    .font(.caption.weight(.bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(LocusTheme.accent)
                                    .foregroundStyle(.black)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 4)
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button(role: .destructive) {
                        routeToDelete = route
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete", systemImage: "trash")
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

    // MARK: - LocalStorage Operations
    private func reloadRoutes() {
        self.routes = SavedRoute.load()
    }

    private func performRename(route: SavedRoute, newName: String) {
        SavedRoute.renameRoute(id: route.id, to: newName)
        session.renameSavedRoute(route, to: newName)
        reloadRoutes()
    }

    private func performDelete(route: SavedRoute) {
        SavedRoute.deleteRoute(id: route.id)
        session.removeSavedRoute(route)
        reloadRoutes()
        routeToDelete = nil
    }
}
