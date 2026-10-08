import SwiftUI
import UIKit

public struct DashboardView: View {
    @ObservedObject public var environment: AppEnvironment
    @Environment(\.openURL) private var openURL
    @State private var showingGoogle = false
    @State private var showingTelegram = false
    public init(environment: AppEnvironment) { self.environment = environment }
    private var state: DashboardViewState { environment.dashboardState }
    private var needsSetup: Bool {
        !state.photosAccess.canRead || state.accessibleLibraryTotal == nil ||
        (!state.googleStatus.isConnected && !state.telegramStatus.isConnected)
    }

    public var body: some View {
        NavigationStack {
            List {
                if needsSetup { setupSection }
                if state.photosAccess.canRead && state.accessibleLibraryTotal != nil {
                    Section {
                        OverallActivityCard(state: state.overallState, waitingReason: state.waitingOrErrorReason,
                            libraryTotal: state.accessibleLibraryTotal, savedToBoth: state.savedToBothCount,
                            permissionScope: state.permissionScopeDescription, scanDate: state.scanTimestamp,
                            canPause: state.canPause && state.controlsAvailable,
                            canResume: state.canResume && state.controlsAvailable && state.canStartBackup,
                            canStart: state.canStartBackup && state.controlsAvailable && !state.canPause,
                            onBackUp: environment.requestBackup, onPause: environment.requestPause,
                            onResume: environment.requestResume)
                    }
                    Section("Destinations") {
                        ProviderStatusCard(state: state.googleStatus, onSettingsTapped: { showingGoogle = true })
                        ProviderStatusCard(state: state.telegramStatus, onSettingsTapped: { showingTelegram = true })
                    }
                    if !state.currentTransfers.isEmpty {
                        Section("Uploading now") {
                            ForEach(state.currentTransfers) { CurrentTransferCard(transfer: $0) }
                        }
                    }
                    Section("Your library") {
                        MediaSectionCard(state: state.photosSection)
                        MediaSectionCard(state: state.videosSection)
                    }
                    Section {
                        DisclosureGroup("Backup details") {
                            LabeledContent("Photos access", value: state.permissionScopeDescription)
                            if let date = state.scanTimestamp {
                                LabeledContent("Last scan", value: date.formatted())
                            }
                            if let count = state.confirmedThisSessionCount {
                                LabeledContent("Saved this session", value: String(count))
                            }
                            if let speed = state.currentTransferSpeedBytesPerSec {
                                LabeledContent("Speed", value: ByteCountFormatter.string(fromByteCount: speed, countStyle: .binary) + "/s")
                            }
                            if let eta = state.estimatedRemainingTimeSeconds {
                                LabeledContent("Time remaining", value: Duration.seconds(eta).formatted(.units(allowed: [.hours, .minutes])))
                            }
                            Button("Scan library again", action: environment.requestPhotoLibraryAccess)
                                .disabled(!state.controlsAvailable || state.canPause)
                        }
                    }
                }
            }
            .navigationTitle("Backup")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { environment.selectedTab = .settings } label: {
                        Image(systemName: "gearshape").accessibilityLabel("Settings")
                    }
                }
            }
            .sheet(isPresented: $showingGoogle) { GoogleAuthSheet(environment: environment) }
            .sheet(isPresented: $showingTelegram) { TelegramAuthSheet(environment: environment) }
        }
    }

    private var setupSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Set up your backup").font(.title2.weight(.semibold))
                Text("Choose Photos access, then connect a destination. Uploading starts when you tap Back Up.")
                    .foregroundStyle(.secondary)
            }.padding(.vertical, 8)
            if state.photosAccess == .restricted {
                Label(state.photosAccess.description, systemImage: "lock")
            } else if state.photosAccess == .denied {
                Button("Open Photos permissions") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
            } else if !state.photosAccess.canRead || state.accessibleLibraryTotal == nil {
                Button(action: environment.requestPhotoLibraryAccess) {
                    HStack {
                        Label(state.photosAccess.canRead ? "Scan your library" : "Allow Photos access", systemImage: "photo")
                        if state.isReadingLibrary { Spacer(); ProgressView() }
                    }
                }.disabled(!state.controlsAvailable || state.isReadingLibrary)
            } else {
                Label("\(state.accessibleLibraryTotal ?? 0) accessible items", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            }
            if !state.googleStatus.isConnected {
                Button { showingGoogle = true } label: { Label("Connect Google Photos", systemImage: "photo.stack") }
                    .disabled(!state.controlsAvailable)
            }
            if !state.telegramStatus.isConnected {
                Button { showingTelegram = true } label: { Label("Connect Telegram", systemImage: "paperplane") }
                    .disabled(!state.controlsAvailable)
            }
            if let reason = state.waitingOrErrorReason, case .needsAttention = state.overallState {
                Text(reason).font(.footnote).foregroundStyle(.red)
            }
        }
    }
}
