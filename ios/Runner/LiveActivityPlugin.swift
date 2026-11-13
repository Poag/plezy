import ActivityKit
import Flutter

/// Answers `com.plezy/live_activity`'s `isSupported`/`start`/`update`/`end`,
/// starting and driving the download Live Activity defined in
/// `DownloadActivityAttributes.swift`. The Dart-side counterpart is
/// `LiveActivityService` (`lib/services/live_activity_service.dart`).
///
/// Live Activities require iOS 16.2+; on earlier versions `isSupported`
/// reports false and every other call is a no-op, so the Dart side never
/// attempts to start one.
class LiveActivityPlugin: NSObject, FlutterPlugin {
  private var manager: Any?

  static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "com.plezy/live_activity", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(LiveActivityPlugin(), channel: channel)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "isSupported":
      result(isSupported)
    case "start", "update":
      guard #available(iOS 16.2, *) else {
        result(nil)
        return
      }
      guard let contentState = Self.contentState(from: call.arguments) else {
        result(FlutterError(code: "bad_args", message: "Missing or invalid content state", details: nil))
        return
      }
      if call.method == "start" {
        typedManager.start(contentState: contentState)
      } else {
        typedManager.update(contentState: contentState)
      }
      result(nil)
    case "end":
      if #available(iOS 16.2, *) {
        typedManager.end()
      }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private var isSupported: Bool {
    guard #available(iOS 16.2, *) else { return false }
    return ActivityAuthorizationInfo().areActivitiesEnabled
  }

  @available(iOS 16.2, *)
  private var typedManager: DownloadActivityManager {
    if let existing = manager as? DownloadActivityManager { return existing }
    let created = DownloadActivityManager()
    manager = created
    return created
  }

  @available(iOS 16.2, *)
  private static func contentState(from arguments: Any?) -> DownloadActivityAttributes.ContentState? {
    guard let args = arguments as? [String: Any] else { return nil }
    guard
      let activeCount = args["activeCount"] as? Int,
      let queuedCount = args["queuedCount"] as? Int,
      let overallProgress = args["overallProgress"] as? Double,
      let downloadedBytes = args["downloadedBytes"] as? Int,
      let totalBytes = args["totalBytes"] as? Int,
      let speedBytesPerSec = args["speedBytesPerSec"] as? Double
    else { return nil }
    return DownloadActivityAttributes.ContentState(
      activeCount: activeCount,
      queuedCount: queuedCount,
      overallProgress: overallProgress,
      downloadedBytes: downloadedBytes,
      totalBytes: totalBytes,
      speedBytesPerSec: speedBytesPerSec,
      primaryTitle: args["primaryTitle"] as? String
    )
  }
}

/// Owns the single `Activity<DownloadActivityAttributes>` for its
/// `LiveActivityPlugin`. Split out from the plugin itself because a stored
/// property of an iOS-16.2+ type would force that availability onto the
/// whole plugin class, which is instantiated unconditionally at app launch.
@available(iOS 16.2, *)
private final class DownloadActivityManager {
  private var activity: Activity<DownloadActivityAttributes>?

  func start(contentState: DownloadActivityAttributes.ContentState) {
    guard activity == nil else {
      update(contentState: contentState)
      return
    }
    activity = try? Activity.request(
      attributes: DownloadActivityAttributes(),
      content: .init(state: contentState, staleDate: nil)
    )
  }

  func update(contentState: DownloadActivityAttributes.ContentState) {
    guard let activity else { return }
    Task {
      await activity.update(.init(state: contentState, staleDate: nil))
    }
  }

  func end() {
    guard let activity else { return }
    self.activity = nil
    Task {
      await activity.end(.init(state: activity.content.state, staleDate: nil), dismissalPolicy: .immediate)
    }
  }
}
