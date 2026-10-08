import SwiftUI
import Photos
import CloudifiedCore
#if canImport(UIKit)
import UIKit
public typealias PlatformImage = UIImage
#elseif canImport(AppKit)
import AppKit
public typealias PlatformImage = NSImage
#endif

public struct NotUploadedView: View {
    @ObservedObject public var environment: AppEnvironment
    @State private var selectedItemForDetails: NotUploadedItem?

    public init(environment: AppEnvironment) {
        self.environment = environment
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filters section
                filtersHeader
                    .padding()
                    .background(Color(.secondarySystemBackground))

                // Content list or empty state
                if environment.notUploadedState.filteredItems.isEmpty {
                    emptyStateView
                } else {
                    List {
                        ForEach(environment.notUploadedState.filteredItems) { item in
                            NotUploadedRow(item: item) {
                                selectedItemForDetails = item
                            } onRetry: {
                                environment.retryItem(item)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Not Uploaded")
            .sheet(item: $selectedItemForDetails) { item in
                NotUploadedDetailSheet(item: item)
            }
        }
    }

    private var filtersHeader: some View {
        VStack(spacing: 8) {
            Picker("Destination", selection: $environment.notUploadedState.destinationFilter) {
                ForEach(DestinationFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .pickerStyle(.segmented)

            HStack(spacing: 12) {
                Picker("Media", selection: $environment.notUploadedState.mediaTypeFilter) {
                    ForEach(MediaTypeFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)

                Spacer()

                Picker("Status", selection: $environment.notUploadedState.statusFilter) {
                    ForEach(FailureStatusFilter.allCases) { filter in
                        Text(filter.rawValue).tag(filter)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44))
                .foregroundColor(.secondary)
            Text("No Failed or Pending Uploads")
                .font(.headline)
                .foregroundColor(.primary)
            Text("The library has not been scanned yet, or all processed items were successfully confirmed. Failed or blocked uploads will appear here with diagnostic details.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Row displaying an asset failure or pending item.
public struct NotUploadedRow: View {
    public let item: NotUploadedItem
    public let onTap: () -> Void
    public let onRetry: () -> Void

    public var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Small error-identification thumbnail (<=100 cached / 16 MiB, cancellable)
                NotUploadedThumbnailView(localIdentifier: item.localIdentifier, mediaType: item.mediaType)

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(item.filename)
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Text(item.attemptText)
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .clipShape(Capsule())
                    }

                    HStack(spacing: 6) {
                        Text(item.provider)
                            .font(.caption2.bold())
                            .foregroundColor(.secondary)
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(item.mediaType)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        if let duration = item.durationSeconds {
                            Text("•")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(formatDuration(duration))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }

                    Text(item.plainLanguageReason)
                        .font(.caption)
                        .foregroundColor(.red)
                        .lineLimit(2)

                    HStack {
                        Text(item.captureDate, style: .date)
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        Spacer()

                        Button(action: onRetry) {
                            Text("Retry")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                        .tint(.accentColor)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.minute, .second]
        formatter.unitsStyle = .positional
        formatter.zeroFormattingBehavior = .pad
        return formatter.string(from: seconds) ?? ""
    }
}

/// Small cancellable thumbnail view bounded by a <=100 item / 16 MiB cache.
@MainActor
final class RowThumbnailLoader: ObservableObject {
    @Published var image: PlatformImage? = nil
    private var requestID: PHImageRequestID? = nil

    private static let cache: NSCache<NSString, PlatformImage> = {
        let c = NSCache<NSString, PlatformImage>()
        c.countLimit = 100
        c.totalCostLimit = 16 * 1024 * 1024 // 16 MiB
        return c
    }()

    func load(localIdentifier: String) {
        guard !localIdentifier.isEmpty else { return }
        if let cached = Self.cache.object(forKey: localIdentifier as NSString) {
            self.image = cached
            return
        }
        let fetch = PHAsset.fetchAssets(withLocalIdentifiers: [localIdentifier], options: nil)
        guard let asset = fetch.firstObject else { return }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false // Local access only; no cloud preview fetch
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isSynchronous = false

        requestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 96, height: 96),
            contentMode: .aspectFill,
            options: options
        ) { [weak self] img, _ in
            guard let img else { return }
            let bytes = Int(img.size.width * img.size.height * 4)
            Self.cache.setObject(img, forKey: localIdentifier as NSString, cost: bytes)
            Task { @MainActor in
                self?.image = img
            }
        }
    }

    func cancel() {
        if let req = requestID {
            PHImageManager.default().cancelImageRequest(req)
            requestID = nil
        }
    }
}

struct NotUploadedThumbnailView: View {
    let localIdentifier: String
    let mediaType: String
    @StateObject private var loader = RowThumbnailLoader()

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.tertiarySystemFill))
                .frame(width: 48, height: 48)

            if let img = loader.image {
                #if canImport(UIKit)
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipped()
                    .cornerRadius(6)
                #elseif canImport(AppKit)
                Image(nsImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipped()
                    .cornerRadius(6)
                #endif
            } else {
                Image(systemName: mediaType.localizedCaseInsensitiveContains("Video") ? "video" : "photo")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .onAppear {
            loader.load(localIdentifier: localIdentifier)
        }
        .onDisappear {
            loader.cancel()
        }
    }
}


/// Detailed inspector sheet for an individual failed asset.
public struct NotUploadedDetailSheet: View {
    public let item: NotUploadedItem
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationStack {
            List {
                Section(header: Text("Asset Details")) {
                    labeledRow(label: "Filename", value: item.filename)
                    labeledRow(label: "Media Type", value: item.mediaType)
                    labeledRow(label: "Destination", value: item.provider)
                    labeledRow(label: "Capture Date", value: item.captureDate.formatted())
                    labeledRow(label: "Attempts", value: "\(item.attemptCount) of \(item.maxAttempts)")
                }

                Section(header: Text("Diagnostic Information")) {
                    labeledRow(label: "Stage", value: item.stage)
                    labeledRow(label: "Category", value: item.errorCategory)
                    if let code = item.technicalCode {
                        labeledRow(label: "Technical Code", value: code)
                    }
                    labeledRow(label: "Reason", value: item.plainLanguageReason)
                    if let remedy = item.suggestedRemedy {
                        labeledRow(label: "Suggested Remedy", value: remedy)
                    }
                }

                if !item.confirmedComponents.isEmpty || !item.missingObligations.isEmpty {
                    Section(header: Text("Resource Components")) {
                        if !item.confirmedComponents.isEmpty {
                            labeledRow(label: "Confirmed", value: item.confirmedComponents.joined(separator: ", "))
                        }
                        if !item.missingObligations.isEmpty {
                            labeledRow(label: "Missing", value: item.missingObligations.joined(separator: ", "))
                        }
                    }
                }
            }
            .navigationTitle("Failure Details")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func labeledRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}
