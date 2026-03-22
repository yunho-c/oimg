import Cocoa

@_silgen_name("oimg_service_run_request")
private func oimg_service_run_request(_ request: UnsafePointer<CChar>) -> UnsafeMutablePointer<CChar>?

@_silgen_name("oimg_service_free_string")
private func oimg_service_free_string(_ value: UnsafeMutablePointer<CChar>?)

private enum CompressionServiceAction: String, Codable {
  case compress
  case compressKeepOriginal = "compress_keep_original"
}

private struct CompressionServiceRequest: Codable {
  let action: CompressionServiceAction
  let paths: [String]
}

private struct CompressionServiceResponse: Decodable {
  let successCount: Int
  let failureCount: Int
  let items: [CompressionServiceItem]
}

private struct CompressionServiceItem: Decodable {
  let inputPath: String
  let outputPath: String?
  let error: String?
}

final class CompressionServiceProvider: NSObject {
  private static let supportedExtensions: Set<String> = [
    "png",
    "jpg",
    "jpeg",
    "gif",
    "bmp",
    "webp",
    "tif",
    "tiff",
  ]

  private let encoder = JSONEncoder()
  private let decoder: JSONDecoder = {
    let decoder = JSONDecoder()
    decoder.keyDecodingStrategy = .convertFromSnakeCase
    return decoder
  }()

  @objc(runCompressionService:userData:error:)
  func runCompressionService(
    _ pasteboard: NSPasteboard,
    userData: String?,
    error: AutoreleasingUnsafeMutablePointer<NSString?>
  ) {
    guard let actionKey = userData, let action = CompressionServiceAction(rawValue: actionKey) else {
      error.pointee = "Unsupported compression action." as NSString
      return
    }

    let urls = fileURLs(from: pasteboard)
    if urls.isEmpty {
      error.pointee = "Select at least one supported image file." as NSString
      return
    }

    var accessedUrls: [URL] = []
    for url in urls where url.startAccessingSecurityScopedResource() {
      accessedUrls.append(url)
    }
    defer {
      for url in accessedUrls {
        url.stopAccessingSecurityScopedResource()
      }
    }

    let request = CompressionServiceRequest(
      action: action,
      paths: urls.map(\.path)
    )

    do {
      let response = try runRustRequest(request)
      if response.successCount == 0, let message = response.items.first?.error {
        error.pointee = message as NSString
        return
      }

      if action == .compressKeepOriginal {
        let outputURLs = response.items.compactMap { item -> URL? in
          guard let outputPath = item.outputPath, outputPath != item.inputPath else {
            return nil
          }
          return URL(fileURLWithPath: outputPath)
        }

        if !outputURLs.isEmpty {
          NSWorkspace.shared.activateFileViewerSelecting(outputURLs)
        }
      }
    } catch let serviceError {
      error.pointee = serviceError.localizedDescription as NSString
    }
  }

  private func fileURLs(from pasteboard: NSPasteboard) -> [URL] {
    let readOptions: [NSPasteboard.ReadingOptionKey: Any] = [
      .urlReadingFileURLsOnly: true,
    ]

    if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: readOptions) as? [URL] {
      return filterSupported(urls)
    }

    let fileNamesType = NSPasteboard.PasteboardType("NSFilenamesPboardType")
    if let fileNames = pasteboard.propertyList(forType: fileNamesType) as? [String] {
      return filterSupported(fileNames.map(URL.init(fileURLWithPath:)))
    }

    return []
  }

  private func filterSupported(_ urls: [URL]) -> [URL] {
    urls.filter { url in
      Self.supportedExtensions.contains(url.pathExtension.lowercased())
    }
  }

  private func runRustRequest(_ request: CompressionServiceRequest) throws -> CompressionServiceResponse {
    let requestData = try encoder.encode(request)
    let requestJSON = String(decoding: requestData, as: UTF8.self)

    return try requestJSON.withCString { pointer in
      guard let responsePointer = oimg_service_run_request(pointer) else {
        throw CompressionServiceError(message: "Rust service returned no response.")
      }

      defer {
        oimg_service_free_string(responsePointer)
      }

      let responseJSON = String(cString: responsePointer)
      return try decoder.decode(
        CompressionServiceResponse.self,
        from: Data(responseJSON.utf8)
      )
    }
  }
}

private struct CompressionServiceError: LocalizedError {
  let message: String

  var errorDescription: String? {
    message
  }
}
