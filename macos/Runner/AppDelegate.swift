import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private let fileOpenChannelName = "oimg/file_open"
  private var fileOpenChannel: FlutterMethodChannel?
  private var pendingOpenRequests: [[String]] = []
  private var fileOpenChannelReady = false
  private let compressionServiceProvider = CompressionServiceProvider()
  private var securityScopedUrlsByPath: [String: URL] = [:]

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
      } else if call.method == "pickFiles" {
        result(
          self.presentOpenPanel(
            canChooseFiles: true,
            canChooseDirectories: false,
            allowsMultipleSelection: true
          )
        )
      } else if call.method == "pickFolder" {
        result(
          self.presentOpenPanel(
            canChooseFiles: false,
            canChooseDirectories: true,
            allowsMultipleSelection: false
          )
        )
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    fileOpenChannel = channel
    flushPendingOpenRequests()
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.servicesProvider = compressionServiceProvider
    NSUpdateDynamicServices()
    attachIfPossible()
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    retainSecurityScopedAccess(for: filenames.map(URL.init(fileURLWithPath:)))
    queueOpenRequest(filenames)
    attachIfPossible()
    sender.reply(toOpenOrPrint: .success)
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    retainSecurityScopedAccess(for: urls)
    let filePaths = urls.filter(\.isFileURL).map(\.path)
    if !filePaths.isEmpty {
      queueOpenRequest(filePaths)
      attachIfPossible()
    }

    let nonFileUrls = urls.filter { !$0.isFileURL }
    if !nonFileUrls.isEmpty {
      super.application(application, open: nonFileUrls)
    }
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

  private func retainSecurityScopedAccess(for urls: [URL]) {
    for url in urls where url.isFileURL {
      let path = url.path
      if securityScopedUrlsByPath[path] != nil {
        continue
      }

      if url.startAccessingSecurityScopedResource() {
        securityScopedUrlsByPath[path] = url
      }
    }
  }

  private func presentOpenPanel(
    canChooseFiles: Bool,
    canChooseDirectories: Bool,
    allowsMultipleSelection: Bool
  ) -> [String] {
    let panel = NSOpenPanel()
    panel.canChooseFiles = canChooseFiles
    panel.canChooseDirectories = canChooseDirectories
    panel.allowsMultipleSelection = allowsMultipleSelection
    panel.resolvesAliases = true
    panel.canCreateDirectories = false
    panel.title = canChooseDirectories ? "Open Folder" : "Open Files"
    panel.message = canChooseDirectories
      ? "Choose a folder to open in OIMG."
      : "Choose one or more image files to open in OIMG."

    guard panel.runModal() == .OK else {
      return []
    }

    retainSecurityScopedAccess(for: panel.urls)
    return panel.urls.filter(\.isFileURL).map(\.path)
  }
}
