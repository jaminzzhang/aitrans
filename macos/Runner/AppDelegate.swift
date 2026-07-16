import Cocoa
import FlutterMacOS

final class MenuBarVisibilityPreferences {
  static let defaultKey = "menuBarItemVisible"

  private let defaults: UserDefaults
  private let key: String

  init(defaults: UserDefaults = .standard, key: String = defaultKey) {
    self.defaults = defaults
    self.key = key
  }

  var isVisible: Bool {
    get { defaults.object(forKey: key) as? Bool ?? true }
    set { defaults.set(newValue, forKey: key) }
  }
}

protocol MenuBarStatusItem: AnyObject {
  func configure(
    image: NSImage?,
    fallbackTitle: String,
    toolTip: String,
    target: AnyObject,
    action: Selector
  )
  func remove()
}

final class AppKitMenuBarStatusItem: MenuBarStatusItem {
  private let statusBar: NSStatusBar
  private let statusItem: NSStatusItem

  init(statusBar: NSStatusBar = .system) {
    self.statusBar = statusBar
    statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
  }

  func configure(
    image: NSImage?,
    fallbackTitle: String,
    toolTip: String,
    target: AnyObject,
    action: Selector
  ) {
    guard let button = statusItem.button else { return }
    button.image = image
    button.title = image == nil ? fallbackTitle : ""
    button.toolTip = toolTip
    button.setAccessibilityLabel("AITrans")
    button.target = target
    button.action = action
  }

  func remove() {
    statusBar.removeStatusItem(statusItem)
  }
}

final class MenuBarStatusController: NSObject {
  static let shared = MenuBarStatusController(
    preferences: MenuBarVisibilityPreferences(),
    makeStatusItem: { AppKitMenuBarStatusItem() },
    imageLoader: { NSImage(named: NSImage.Name("MenuBarIcon")) },
    onToggleMainWindow: { MainWindowPresenter.shared.toggleMainWindow() }
  )

  private let preferences: MenuBarVisibilityPreferences
  private let makeStatusItem: () -> MenuBarStatusItem
  private let imageLoader: () -> NSImage?
  private let onToggleMainWindow: () -> Void
  private var statusItem: MenuBarStatusItem?

  init(
    preferences: MenuBarVisibilityPreferences,
    makeStatusItem: @escaping () -> MenuBarStatusItem,
    imageLoader: @escaping () -> NSImage?,
    onToggleMainWindow: @escaping () -> Void
  ) {
    self.preferences = preferences
    self.makeStatusItem = makeStatusItem
    self.imageLoader = imageLoader
    self.onToggleMainWindow = onToggleMainWindow
  }

  var isVisible: Bool { statusItem != nil }

  func applyStoredPreference() {
    setVisible(preferences.isVisible)
  }

  func setVisible(_ visible: Bool) {
    if visible {
      guard statusItem == nil else {
        preferences.isVisible = true
        return
      }
      let newItem = makeStatusItem()
      let image = imageLoader()
      image?.isTemplate = true
      newItem.configure(
        image: image,
        fallbackTitle: "A",
        toolTip: "显示或关闭 AITrans",
        target: self,
        action: #selector(handleStatusItemClick(_:))
      )
      statusItem = newItem
    } else {
      statusItem?.remove()
      statusItem = nil
    }
    preferences.isVisible = visible
  }

  @objc private func handleStatusItemClick(_ sender: Any?) {
    onToggleMainWindow()
  }
}

enum MenuBarPreferenceMethodError: Error, Equatable {
  case invalidVisibility
  case unsupportedMethod
}

final class MenuBarPreferenceMethodHandler {
  private let getVisibility: () -> Bool
  private let setVisibility: (Bool) -> Void

  init(
    getVisibility: @escaping () -> Bool,
    setVisibility: @escaping (Bool) -> Void
  ) {
    self.getVisibility = getVisibility
    self.setVisibility = setVisibility
  }

  convenience init(controller: MenuBarStatusController) {
    self.init(
      getVisibility: { controller.isVisible },
      setVisibility: { controller.setVisible($0) }
    )
  }

  func handle(method: String, arguments: Any?) throws -> Any? {
    switch method {
    case "getVisibility":
      return getVisibility()
    case "setVisibility":
      guard let visible = arguments as? Bool else {
        throw MenuBarPreferenceMethodError.invalidVisibility
      }
      setVisibility(visible)
      return getVisibility()
    default:
      throw MenuBarPreferenceMethodError.unsupportedMethod
    }
  }
}

final class MenuBarPreferenceBridge {
  static let shared = MenuBarPreferenceBridge()

  private var channel: FlutterMethodChannel?

  func attach(
    binaryMessenger: FlutterBinaryMessenger,
    controller: MenuBarStatusController = .shared
  ) {
    let channel = FlutterMethodChannel(
      name: "com.aitrans/menu_bar_preferences",
      binaryMessenger: binaryMessenger
    )
    let handler = MenuBarPreferenceMethodHandler(controller: controller)
    self.channel = channel
    channel.setMethodCallHandler { call, result in
      do {
        result(try handler.handle(method: call.method, arguments: call.arguments))
      } catch MenuBarPreferenceMethodError.unsupportedMethod {
        result(FlutterMethodNotImplemented)
      } catch {
        result(
          FlutterError(
            code: "invalid_menu_bar_visibility",
            message: "状态栏可见性参数无效。",
            details: nil
          )
        )
      }
    }
  }
}

protocol MainWindowPresentable: AnyObject {
  var isKeyWindow: Bool { get }
  var isMiniaturized: Bool { get }
  var isVisible: Bool { get }
  func deminiaturize(_ sender: Any?)
  func makeKeyAndOrderFront(_ sender: Any?)
  func close()
}

extension NSWindow: MainWindowPresentable {}

final class MainWindowRegistry {
  static let shared = MainWindowRegistry()

  private(set) var mainWindow: MainWindowPresentable?

  func register(_ window: MainWindowPresentable) {
    mainWindow = window
  }
}

final class MainWindowPresenter {
  static let shared = MainWindowPresenter(
    windowProvider: {
      MainWindowRegistry.shared.mainWindow
        ?? NSApp.windows.first { $0 is MainFlutterWindow }
    },
    activateApplication: {
      NSApp.unhide(nil)
      NSApp.activate(ignoringOtherApps: true)
    }
  )

  private let windowProvider: () -> MainWindowPresentable?
  private let activateApplication: () -> Void

  init(
    windowProvider: @escaping () -> MainWindowPresentable?,
    activateApplication: @escaping () -> Void
  ) {
    self.windowProvider = windowProvider
    self.activateApplication = activateApplication
  }

  @discardableResult
  func showMainWindow() -> Bool {
    guard let window = windowProvider() else { return false }
    return show(window)
  }

  @discardableResult
  func toggleMainWindow() -> Bool {
    guard let window = windowProvider() else { return false }
    if window.isVisible && window.isKeyWindow && !window.isMiniaturized {
      window.close()
      return false
    }
    return show(window)
  }

  private func show(_ window: MainWindowPresentable) -> Bool {
    if window.isMiniaturized {
      window.deminiaturize(nil)
    }
    activateApplication()
    window.makeKeyAndOrderFront(nil)
    return true
  }
}

final class ApplicationLifecycleController {
  private let showMainWindow: () -> Bool

  init(showMainWindow: @escaping () -> Bool) {
    self.showMainWindow = showMainWindow
  }

  func handleDockReopen() -> Bool {
    _ = showMainWindow()
    return false
  }
}

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
      MainWindowPresenter.shared.showMainWindow()
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

final class MacOSServiceRegistration {
  typealias ServicesProviderSetter = (NSObject) -> Void
  typealias DynamicServicesRefresher = () -> Void

  private let setServicesProvider: ServicesProviderSetter
  private let refreshDynamicServices: DynamicServicesRefresher
  private var didRegister = false

  init(
    setServicesProvider: @escaping ServicesProviderSetter = { NSApp.servicesProvider = $0 },
    refreshDynamicServices: @escaping DynamicServicesRefresher = { NSUpdateDynamicServices() }
  ) {
    self.setServicesProvider = setServicesProvider
    self.refreshDynamicServices = refreshDynamicServices
  }

  func ensureRegistered(provider: NSObject) {
    guard !didRegister else { return }
    setServicesProvider(provider)
    refreshDynamicServices()
    didRegister = true
  }
}

@main
class AppDelegate: FlutterAppDelegate {
  private lazy var translationServiceProvider = ExternalTranslationServiceProvider { request in
    ExternalTranslationBridge.shared.receive(request)
  }
  private let serviceRegistration = MacOSServiceRegistration()
  private let lifecycleController = ApplicationLifecycleController(
    showMainWindow: { MainWindowPresenter.shared.showMainWindow() }
  )

  override func applicationDidFinishLaunching(_ notification: Notification) {
    serviceRegistration.ensureRegistered(provider: translationServiceProvider)
    MenuBarStatusController.shared.applyStoredPreference()
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    return lifecycleController.handleDockReopen()
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}
