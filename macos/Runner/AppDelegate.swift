import Cocoa
import FlutterMacOS

enum ServiceRequestError: LocalizedError, Equatable {
  case invalidItemCount
  case plainTextUnavailable

  var errorDescription: String? {
    switch self {
    case .invalidItemCount:
      return "AITrans 只能处理单段纯文本。"
    case .plainTextUnavailable:
      return "AITrans 未收到可翻译的纯文本。"
    }
  }
}

enum ServicePasteboardParser {
  static func parse(_ pasteboard: NSPasteboard) throws -> String {
    guard let items = pasteboard.pasteboardItems, items.count == 1 else {
      throw ServiceRequestError.invalidItemCount
    }
    guard let text = items[0].string(forType: .string) else {
      throw ServiceRequestError.plainTextUnavailable
    }
    return text
  }
}

struct NativeExternalTranslationRequest: Equatable {
  let sequence: Int64
  let text: String
}

final class ExternalTranslationServiceProvider: NSObject {
  typealias RequestHandler = (NativeExternalTranslationRequest) -> Void

  private let onRequest: RequestHandler
  private var sequence: Int64 = 0

  init(onRequest: @escaping RequestHandler) {
    self.onRequest = onRequest
  }

  @objc func translateSelection(
    _ pasteboard: NSPasteboard,
    userData: String?,
    error errorPointer: AutoreleasingUnsafeMutablePointer<NSString?>?
  ) {
    do {
      let text = try ServicePasteboardParser.parse(pasteboard)
      precondition(sequence < Int64.max, "Service request sequence exhausted")
      sequence += 1
      onRequest(NativeExternalTranslationRequest(sequence: sequence, text: text))
    } catch let requestError as ServiceRequestError {
      errorPointer?.pointee = requestError.localizedDescription as NSString
    } catch {
      errorPointer?.pointee = "AITrans 无法处理所选文本。" as NSString
    }
  }
}

final class ExternalTranslationRequestBuffer {
  typealias Sender = (NativeExternalTranslationRequest) -> Void

  private var sender: Sender?
  private(set) var pendingRequest: NativeExternalTranslationRequest?

  func receive(_ request: NativeExternalTranslationRequest) {
    guard let sender else {
      pendingRequest = request
      return
    }
    sender(request)
  }

  func attach(sender: @escaping Sender) {
    self.sender = sender
    guard let pendingRequest else { return }
    self.pendingRequest = nil
    sender(pendingRequest)
  }
}

final class ExternalTranslationBridge {
  static let shared = ExternalTranslationBridge()

  private let buffer = ExternalTranslationRequestBuffer()
  private var channel: FlutterMethodChannel?

  func receive(_ request: NativeExternalTranslationRequest) {
    DispatchQueue.main.async {
      NSApp.activate(ignoringOtherApps: true)
      NSApp.windows.first?.makeKeyAndOrderFront(nil)
      self.buffer.receive(request)
    }
  }

  func attach(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.aitrans/external_translation",
      binaryMessenger: binaryMessenger
    )
    self.channel = channel
    channel.setMethodCallHandler { [weak self, weak channel] call, result in
      guard call.method == "ready" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.buffer.attach { [weak channel] request in
        channel?.invokeMethod(
          "externalTranslationRequest",
          arguments: [
            "sequence": request.sequence,
            "source": "macosService",
            "text": request.text,
          ]
        )
      }
      result(nil)
    }
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  private lazy var translationServiceProvider = ExternalTranslationServiceProvider { request in
    ExternalTranslationBridge.shared.receive(request)
  }

  override func applicationDidFinishLaunching(_ notification: Notification) {
    NSApp.servicesProvider = translationServiceProvider
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
