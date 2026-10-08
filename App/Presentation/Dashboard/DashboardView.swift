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
                if needsSetup {
                    setupSection
                }
                
                if state.photosAccess.canRead && state.accessibleLibraryTotal != nil {
                    Section {
                        OverallActivityCard(
                            state: state.overallState,
                            waitingReason: state.waitingOrErrorReason,
                            libraryTotal: state.accessibleLibraryTotal,
                            savedToBoth: state.savedToBothCount,
                            permissionScope: state.permissionScopeDescription,
                            scanDate: state.scanTimestamp,
                            canPause: state.canPause && state.controlsAvailable,
                            canResume: state.canResume && state.controlsAvailable && state.canStartBackup,
                            canStart: state.canStartBackup && state.controlsAvailable && !state.canPause,
                            onBackUp: environment.requestBackup,
                            onPause: environment.requestPause,
                            onResume: environment.requestResume
                        )
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
                        NavigationLink("Backup Details") {
                            backupDetailsView
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Dashboard")
            .sheet(isPresented: $showingGoogle) { GoogleAuthSheet(environment: environment) }
            .sheet(isPresented: $showingTelegram) { TelegramAuthSheet(environment: environment) }
        }
    }

    private var setupSection: some View {
        Section {
            VStack(alignment: .center, spacing: 12) {
                Image(systemName: "cloud.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
                    .padding(.top, 16)
                    
                Text("Set up Cloudified")
                    .font(.title2.weight(.semibold))
                    
                Text("Allow Photos access and connect at least one destination to start backing up your library safely.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }
            .frame(maxWidth: .infinity)
            
            if state.photosAccess == .restricted {
                Label(state.photosAccess.description, systemImage: "lock")
                    .foregroundStyle(.secondary)
            } else if state.photosAccess == .denied {
                Button("Open Settings to Allow Photos") { openURL(URL(string: UIApplication.openSettingsURLString)!) }
            } else if !state.photosAccess.canRead || state.accessibleLibraryTotal == nil {
                Button(action: environment.requestPhotoLibraryAccess) {
                    HStack {
                        Text(state.photosAccess.canRead ? "Scan your library" : "Allow Photos access")
                        Spacer()
                        if state.isReadingLibrary { ProgressView() } else { Image(systemName: "chevron.right").foregroundStyle(.secondary) }
                    }
                }
                .disabled(!state.controlsAvailable || state.isReadingLibrary)
            } else {
                HStack {
                    Text("Photos Access")
                    Spacer()
                    Text("\(state.accessibleLibraryTotal ?? 0) items").foregroundStyle(.secondary)
                    Image(systemName: "checkmark.circle.fill").foregroundColor(.green)
                }
            }
            
            if !state.googleStatus.isConnected {
                Button(action: { showingGoogle = true }) {
                    HStack {
                        Text("Connect Google Photos")
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                }
                .disabled(!state.controlsAvailable)
            }
            
            if !state.telegramStatus.isConnected {
                Button(action: { showingTelegram = true }) {
                    HStack {
                        Text("Connect Telegram")
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                }
                .disabled(!state.controlsAvailable)
            }
            
            if let reason = state.waitingOrErrorReason, case .needsAttention = state.overallState {
                Text(reason).font(.footnote).foregroundStyle(.red)
            }
        }
    }
    
    private var backupDetailsView: some View {
        List {
            Section("Access & Stats") {
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
            }
            
            Section {
                Button("Scan library again", action: environment.requestPhotoLibraryAccess)
                    .disabled(!state.controlsAvailable || state.canPause)
            }
        }
        .navigationTitle("Backup Details")
        .navigationBarTitleDisplayMode(.inline)
    }
}
