import SwiftUI
import AppKit

struct RootView: View {
    @StateObject private var viewModel = AppViewModel.makeForLaunch()

    var body: some View {
        ZStack(alignment: .bottom) {
            NavigationSplitView {
                SidebarView(viewModel: viewModel)
                    .navigationSplitViewColumnWidth(min: 200, ideal: 210, max: 260)
            } content: {
                ContentShellView(viewModel: viewModel)
                    .navigationSplitViewColumnWidth(min: 340, ideal: 440)
            } detail: {
                DetailShellView(viewModel: viewModel)
                    .navigationSplitViewColumnWidth(min: 340, ideal: 380)
            }
            .frame(minWidth: 820, minHeight: 560)
            .background(
                LinearGradient(
                    colors: [Color(nsColor: .windowBackgroundColor), AppTheme.accent.opacity(0.03)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )

            if let toastMessage = viewModel.toastMessage {
                ToastView(message: toastMessage)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.bottom, 24)
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.88), value: viewModel.selectedSection)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: viewModel.selectedArticle)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: viewModel.toastMessage)
        .sheet(item: $viewModel.pendingImport) { analysis in
            ImportMappingSheet(viewModel: viewModel, analysis: analysis)
        }
    }
}

private struct ContentShellView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        switch viewModel.selectedSection ?? .dashboard {
        case .dashboard:
            DashboardView(viewModel: viewModel)
        case .search:
            SearchView(viewModel: viewModel)
        case .library:
            LibraryListView(viewModel: viewModel)
        case .enrich:
            EnrichView(viewModel: viewModel)
        case .slides:
            SlidesView(viewModel: viewModel)
        case .settings:
            SettingsView(viewModel: viewModel)
        }
    }
}

private struct DetailShellView: View {
    @ObservedObject var viewModel: AppViewModel

    var body: some View {
        switch viewModel.selectedSection ?? .dashboard {
        case .library:
            LibraryDetailView(viewModel: viewModel, article: viewModel.activeArticle)
        case .slides:
            SlidePreviewDetailView(article: viewModel.activeArticle, template: viewModel.pptVisualTemplate)
        case .dashboard:
            InsightDetailView()
        case .search:
            LibraryDetailView(viewModel: viewModel, article: viewModel.activeArticle)
        case .enrich:
            EnrichDetailView(viewModel: viewModel)
        case .settings:
            SettingsDetailView(viewModel: viewModel)
        }
    }
}

private struct ToastView: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(AppTheme.ok)
            Text(message)
                .font(.system(size: 13, weight: .semibold))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 11)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().stroke(Color.white.opacity(0.12)))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
    }
}
