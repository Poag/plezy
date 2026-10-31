import ActivityKit
import Foundation

/// Shape of the download Live Activity, shared between the app
/// (`LiveActivityPlugin`, which starts/updates/ends it) and the widget
/// extension (which renders it). Fields mirror `LiveActivityDownloadState`
/// on the Dart side (`lib/services/live_activity_service.dart`).
@available(iOS 16.2, *)
struct DownloadActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    var activeCount: Int
    var queuedCount: Int
    var overallProgress: Double
    var downloadedBytes: Int
    var totalBytes: Int
    var speedBytesPerSec: Double
    var primaryTitle: String?
  }
}
