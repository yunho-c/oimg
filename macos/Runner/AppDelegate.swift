import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let fileOpenChannelName = "oimg/file_open"
  private var fileOpenChannel: FlutterMethodChannel?
  private var pendingOpenRequests: [[String]] = []
  private var fileOpenChannelReady = false

  func attachFileOpenChannel(to controller: FlutterViewController) {
    guard fileOpenChannel == nil else {
      flushPendingOpenRequests()
      return
    }

    let channel = FlutterMethodChannel(
      name: fileOpenChannelName,
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "unavailable", message: "App delegate unavailable", details: nil))
        return
      }

      if call.method == "ready" {
        self.fileOpenChannelReady = true
        self.flushPendingOpenRequests()
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    fileOpenChannel = channel
    flushPendingOpenRequests()
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
    attachIfPossible()
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    queueOpenRequest(filenames)
    attachIfPossible()
    sender.reply(toOpenOrPrint: .success)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    true
  }

  private func attachIfPossible() {
    guard let controller = NSApp.windows
      .compactMap({ $0.contentViewController as? FlutterViewController })
      .first
    else {
      return
    }

    attachFileOpenChannel(to: controller)
  }

  private func queueOpenRequest(_ paths: [String]) {
    guard !paths.isEmpty else {
      return
    }

    pendingOpenRequests.append(paths)
    flushPendingOpenRequests()
  }

  private func flushPendingOpenRequests() {
    guard fileOpenChannelReady, let fileOpenChannel else {
      return
    }

    for paths in pendingOpenRequests {
      fileOpenChannel.invokeMethod("openFiles", arguments: paths)
    }
    pendingOpenRequests.removeAll()
  }
}
