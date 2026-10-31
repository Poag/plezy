import ActivityKit
import SwiftUI
import WidgetKit

@available(iOS 16.2, *)
struct DownloadLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
      DownloadLockScreenView(state: context.state)
        .activityBackgroundTint(Color.black)
        .activitySystemActionForegroundColor(Color.white)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Image(systemName: "arrow.down.circle.fill")
            .font(.title2)
            .foregroundStyle(.tint)
        }
        DynamicIslandExpandedRegion(.trailing) {
          Text(context.state.progressPercentText)
            .font(.title3.monospacedDigit())
            .fontWeight(.semibold)
        }
        DynamicIslandExpandedRegion(.bottom) {
          VStack(alignment: .leading, spacing: 6) {
            Text(context.state.titleText)
              .font(.subheadline)
              .lineLimit(1)
            ProgressView(value: context.state.overallProgress)
              .tint(.accentColor)
            Text(context.state.detailText)
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        }
      } compactLeading: {
        Image(systemName: "arrow.down.circle.fill")
      } compactTrailing: {
        Text(context.state.progressPercentText)
          .font(.caption2.monospacedDigit())
      } minimal: {
        Image(systemName: "arrow.down.circle.fill")
      }
    }
  }
}

@available(iOS 16.2, *)
private struct DownloadLockScreenView: View {
  let state: DownloadActivityAttributes.ContentState

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: "arrow.down.circle.fill")
          .foregroundStyle(.tint)
        Text(state.titleText)
          .font(.headline)
          .lineLimit(1)
        Spacer()
        Text(state.progressPercentText)
          .font(.headline.monospacedDigit())
      }
      ProgressView(value: state.overallProgress)
        .tint(.accentColor)
      Text(state.detailText)
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding()
  }
}

@available(iOS 16.2, *)
extension DownloadActivityAttributes.ContentState {
  fileprivate var titleText: String {
    if let primaryTitle, !primaryTitle.isEmpty { return primaryTitle }
    return activeCount > 1 ? "Downloading \(activeCount) items" : "Downloading"
  }

  fileprivate var progressPercentText: String {
    "\(Int((overallProgress * 100).rounded()))%"
  }

  fileprivate var detailText: String {
    let byteCounter = ByteCountFormatter()
    byteCounter.countStyle = .file
    let downloaded = byteCounter.string(fromByteCount: Int64(downloadedBytes))
    let total = totalBytes > 0 ? byteCounter.string(fromByteCount: Int64(totalBytes)) : nil
    var parts = [total != nil ? "\(downloaded) of \(total!)" : downloaded]
    if speedBytesPerSec > 0 {
      parts.append("\(byteCounter.string(fromByteCount: Int64(speedBytesPerSec)))/s")
    }
    if queuedCount > 0 {
      parts.append("\(queuedCount) queued")
    }
    return parts.joined(separator: " · ")
  }
}
