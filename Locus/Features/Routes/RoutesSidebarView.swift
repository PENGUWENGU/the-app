import SwiftUI
import CoreLocation
import UIKit

/// Sidebar UI component in the dashboard that displays the list of saved GPX routes
/// retrieved from local storage, with one-tap options to load or delete each route.
public struct RoutesSidebarView: View {
    @EnvironmentObject private var session: SpoofSession
    @EnvironmentObject private var pairing: PairingStore

    @Binding public var isOpen: Bool
    public var onLoadRoute: ((SavedRoute) -> Void)?

    @State private var routes: [SavedRoute] = []
    @State private var searchQuery: String = ""
    @State private var routeToDelete: SavedRoute?
    @State private var showDeleteConfirm = false
    @State private var selectedRouteForDetails: SavedRoute? = nil

    public init(isOpen: Binding<Bool>, onLoadRoute: ((SavedRoute) -> Void)? = nil) {
        self._isOpen = isOpen
        self.onLoadRoute = onLoadRoute
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
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                // Dimmed backdrop
                if isOpen {
                    Color.black.opacity(0.45)
                        .ignoresSafeArea()
                        .transition(.opacity)
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isOpen = false
                            }
                        }
                }

                // Sidebar drawer
                if isOpen {
                    sidebarContent
                        .frame(width: min(320, proxy.size.width * 0.82))
                        .frame(maxHeight: .infinity)
                        .background(
                            Color(uiColor: .systemBackground)
                                .opacity(0.95)
                                .ignoresSafeArea()
                        )
                        .overlay(alignment: .trailing) {
                            Rectangle()
                                .fill(LocusTheme.panelStroke)
                                .frame(width: 1)
                                .ignoresSafeArea()
                        }
                        .transition(.move(edge: .leading))
                }
            }
        }
        .onAppear {
            refreshRoutes()
        }
        .onChange(of: isOpen) { _, open in
            if open {
                refreshRoutes()
            }
        }
        .confirmationDialog(
            "Delete Route",
            isPresented: $showDeleteConfirm,
            presenting: routeToDelete
        ) { route in
            Button("Delete \"\(route.name)\"", role: .destructive) {
                deleteRoute(route)
            }
            Button("Cancel", role: .cancel) {
                routeToDelete = nil
            }
        } message: { route in
            Text("Are you sure you want to delete this saved route from storage?")
        }
        .sheet(item: $selectedRouteForDetails) { route in
            RouteDetailView(
                route: route,
                onLoadRoute: { r in
                    loadRoute(r)
                },
                onFollowRoute: { r in
                    session.followRoute(r.clCoordinates, pairing: pairing)
                    withAnimation { isOpen = false }
                }
            )
        }
    }

    private var sidebarContent: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                    .font(.title2)
                    .foregroundStyle(LocusTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved Routes")
                        .font(.headline.weight(.bold))
                    Text("\(routes.count) path\(routes.count == 1 ? "" : "s") in storage")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isOpen = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)
            .padding(.bottom, 12)

            // Search Bar
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.caption)

                TextField("Filter routes…", text: $searchQuery)
                    .font(.subheadline)
                    .textFieldStyle(.plain)

                if !searchQuery.isEmpty {
                    Button {
                        searchQuery = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.primary.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            Divider()

            // Routes List
            if routes.isEmpty {
                emptyStateView
            } else {
                List {
                    ForEach(filteredRoutes) { route in
                        routeRow(route)
                            .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
                            .listRowSeparator(.visible)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    routeToDelete = route
                                    showDeleteConfirm = true
                                } label: {
                                    Label("Delete", systemImage: "trash.fill")
                                }
                            }
                    }
                }
                .listStyle(.plain)
            }

            Spacer(minLength: 0)
        }
    }

    private func routeRow(_ route: SavedRoute) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(route.name)
                .font(.subheadline.weight(.semibold))
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

                Spacer()

                // Details & D3 Chart
                Button {
                    selectedRouteForDetails = route
                } label: {
                    Image(systemName: "chart.xyaxis.line")
                        .font(.caption)
                        .foregroundStyle(LocusTheme.accent)
                }
                .buttonStyle(.plain)

                // Export GPX
                if let url = route.exportToGPXFile() {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                // Delete Button
                Button {
                    routeToDelete = route
                    showDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundStyle(.red.opacity(0.8))
                }
                .buttonStyle(.plain)

                // Load Button
                Button {
                    loadRoute(route)
                } label: {
                    Text("Load")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(LocusTheme.accent)
                        .foregroundStyle(.black)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "map.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text("No GPX Routes")
                .font(.subheadline.weight(.semibold))

            Text("Routes created or imported into Locus appear here for instant loading.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
        }
    }

    // MARK: - Actions
    private func refreshRoutes() {
        self.routes = SavedRoute.load()
    }

    private func loadRoute(_ route: SavedRoute) {
        if let onLoad = onLoadRoute {
            onLoad(route)
        } else {
            session.followRoute(route.clCoordinates, pairing: pairing)
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            isOpen = false
        }
    }

    private func deleteRoute(_ route: SavedRoute) {
        SavedRoute.deleteRoute(id: route.id)
        session.removeSavedRoute(route)
        refreshRoutes()
        routeToDelete = nil
    }
}
