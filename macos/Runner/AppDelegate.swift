import Cocoa
import ApplicationServices
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

enum MenuBarCommand: Int, CaseIterable {
  case translate
  case settings
  case quit

  var title: String {
    switch self {
    case .translate:
      return "翻译"
    case .settings:
      return "设置"
    case .quit:
      return "退出"
    }
  }

  var keyEquivalent: String {
    self == .translate ? "t" : ""
  }

  var keyEquivalentModifierMask: NSEvent.ModifierFlags {
    self == .translate ? [.command] : []
  }

  var systemImageName: String {
    switch self {
    case .translate:
      return "character.bubble"
    case .settings:
      return "gearshape"
    case .quit:
      return "power"
    }
  }
}

enum MenuBarMenuElement: Equatable {
  case command(MenuBarCommand)
  case separator
}

enum MenuBarMenuPresentation {
  static let minimumWidth: CGFloat = 180
  static let elements: [MenuBarMenuElement] = [
    .command(.translate),
    .command(.settings),
    .separator,
    .command(.quit),
  ]
}

protocol MenuBarStatusItem: AnyObject {
  func configure(
    image: NSImage?,
    fallbackTitle: String,
    toolTip: String,
    onPrimaryClick: @escaping () -> Void,
    onMenuCommand: @escaping (MenuBarCommand) -> Void
  )
  func remove()
}

final class AppKitMenuBarStatusItem: MenuBarStatusItem {
  private let statusBar: NSStatusBar
  private let statusItem: NSStatusItem
  private let menu = NSMenu()
  private var onPrimaryClick: (() -> Void)?
  private var onMenuCommand: ((MenuBarCommand) -> Void)?

  init(statusBar: NSStatusBar = .system) {
    self.statusBar = statusBar
    statusItem = statusBar.statusItem(withLength: NSStatusItem.squareLength)
  }

  func configure(
    image: NSImage?,
    fallbackTitle: String,
    toolTip: String,
    onPrimaryClick: @escaping () -> Void,
    onMenuCommand: @escaping (MenuBarCommand) -> Void
  ) {
    guard let button = statusItem.button else { return }
    button.image = image
    button.title = image == nil ? fallbackTitle : ""
    button.toolTip = toolTip
    button.setAccessibilityLabel("AITrans")
    self.onPrimaryClick = onPrimaryClick
    self.onMenuCommand = onMenuCommand
    configureMenu()
    button.target = self
    button.action = #selector(handleStatusItemClick(_:))
    button.sendAction(on: [.leftMouseUp, .rightMouseUp])
  }

  func remove() {
    statusBar.removeStatusItem(statusItem)
  }

  private func configureMenu() {
    menu.removeAllItems()
    menu.minimumWidth = MenuBarMenuPresentation.minimumWidth
    menu.autoenablesItems = false
    for element in MenuBarMenuPresentation.elements {
      guard case let .command(command) = element else {
        menu.addItem(.separator())
        continue
      }
      let item = NSMenuItem(
        title: command.title,
        action: #selector(handleMenuCommand(_:)),
        keyEquivalent: command.keyEquivalent
      )
      item.target = self
      item.tag = command.rawValue
      item.keyEquivalentModifierMask = command.keyEquivalentModifierMask
      if #available(macOS 11.0, *) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 13, weight: .regular)
        item.image = NSImage(
          systemSymbolName: command.systemImageName,
          accessibilityDescription: command.title
        )?.withSymbolConfiguration(configuration)
      }
      menu.addItem(item)
    }
  }

  @objc private func handleStatusItemClick(_ sender: Any?) {
    if NSApp.currentEvent?.type == .rightMouseUp {
      statusItem.menu = menu
      statusItem.button?.performClick(nil)
      statusItem.menu = nil
      return
    }
    onPrimaryClick?()
  }

  @objc private func handleMenuCommand(_ sender: NSMenuItem) {
    guard let command = MenuBarCommand(rawValue: sender.tag) else { return }
    onMenuCommand?(command)
  }
}

final class MenuBarStatusController: NSObject {
  static let shared = MenuBarStatusController(
    preferences: MenuBarVisibilityPreferences(),
    makeStatusItem: { AppKitMenuBarStatusItem() },
    imageLoader: { NSImage(named: NSImage.Name("MenuBarIcon")) },
    onToggleMainWindow: { MainWindowPresenter.shared.toggleMainWindow() },
    onTranslate: { MenuBarTranslationCoordinator.shared.translate() },
    onOpenSettings: { ApplicationCommandBridge.shared.send(.showSettings) },
    onQuit: { NSApp.terminate(nil) }
  )

  private let preferences: MenuBarVisibilityPreferences
  private let makeStatusItem: () -> MenuBarStatusItem
  private let imageLoader: () -> NSImage?
  private let onToggleMainWindow: () -> Void
  private let onTranslate: () -> Void
  private let onOpenSettings: () -> Void
  private let onQuit: () -> Void
  private var statusItem: MenuBarStatusItem?

  init(
    preferences: MenuBarVisibilityPreferences,
    makeStatusItem: @escaping () -> MenuBarStatusItem,
    imageLoader: @escaping () -> NSImage?,
    onToggleMainWindow: @escaping () -> Void,
    onTranslate: @escaping () -> Void,
    onOpenSettings: @escaping () -> Void,
    onQuit: @escaping () -> Void
  ) {
    self.preferences = preferences
    self.makeStatusItem = makeStatusItem
    self.imageLoader = imageLoader
    self.onToggleMainWindow = onToggleMainWindow
    self.onTranslate = onTranslate
    self.onOpenSettings = onOpenSettings
    self.onQuit = onQuit
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
        onPrimaryClick: onToggleMainWindow,
        onMenuCommand: handleMenuCommand
      )
      statusItem = newItem
    } else {
      statusItem?.remove()
      statusItem = nil
    }
    preferences.isVisible = visible
  }

  private func handleMenuCommand(_ command: MenuBarCommand) {
    switch command {
    case .translate:
      onTranslate()
    case .settings:
      onOpenSettings()
    case .quit:
      onQuit()
    }
  }
}

final class AccessibilitySelectedTextReader {
  func readSelectedText(promptIfNeeded: Bool) -> String? {
    let options = [
      kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: promptIfNeeded
    ] as CFDictionary
    guard AXIsProcessTrustedWithOptions(options) else { return nil }

    let systemWideElement = AXUIElementCreateSystemWide()
    var focusedValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
      systemWideElement,
      kAXFocusedUIElementAttribute as CFString,
      &focusedValue
    ) == .success,
      let focusedValue,
      CFGetTypeID(focusedValue) == AXUIElementGetTypeID()
    else {
      return nil
    }

    let focusedElement = unsafeBitCast(focusedValue, to: AXUIElement.self)
    var selectedValue: CFTypeRef?
    guard AXUIElementCopyAttributeValue(
      focusedElement,
      kAXSelectedTextAttribute as CFString,
      &selectedValue
    ) == .success else {
      return nil
    }
    return selectedValue as? String
  }
}

final class MenuBarTranslationTextResolver {
  private let readSelectedText: () -> String?
  private let readClipboardText: () -> String?

  init(
    readSelectedText: @escaping () -> String?,
    readClipboardText: @escaping () -> String?
  ) {
    self.readSelectedText = readSelectedText
    self.readClipboardText = readClipboardText
  }

  func resolve() -> String? {
    normalized(readSelectedText()) ?? normalized(readClipboardText())
  }

  private func normalized(_ text: String?) -> String? {
    guard let text else { return nil }
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
  }
}

enum HotkeySelectionCaptureMethodError: Error, Equatable {
  case unsupportedMethod
}

final class HotkeySelectionCaptureMethodHandler {
  private let resolveText: () -> String?
  private let requestFactory: ExternalTranslationRequestFactory
  private let onRequest: (NativeExternalTranslationRequest) -> Void

  init(
    resolveText: @escaping () -> String?,
    requestFactory: ExternalTranslationRequestFactory,
    onRequest: @escaping (NativeExternalTranslationRequest) -> Void
  ) {
    self.resolveText = resolveText
    self.requestFactory = requestFactory
    self.onRequest = onRequest
  }

  func handle(method: String, arguments: Any?) throws -> Any? {
    guard method == "captureSelection" else {
      throw HotkeySelectionCaptureMethodError.unsupportedMethod
    }
    guard let text = resolveText() else { return false }
    onRequest(requestFactory.makeRequest(text: text, source: .macosHotkey))
    return true
  }
}

final class HotkeySelectionCaptureBridge {
  static let shared: HotkeySelectionCaptureBridge = {
    let selectedTextReader = AccessibilitySelectedTextReader()
    let resolver = MenuBarTranslationTextResolver(
      readSelectedText: {
        selectedTextReader.readSelectedText(promptIfNeeded: true)
      },
      readClipboardText: {
        NSPasteboard.general.string(forType: .string)
      }
    )
    return HotkeySelectionCaptureBridge(
      handler: HotkeySelectionCaptureMethodHandler(
        resolveText: resolver.resolve,
        requestFactory: .shared,
        onRequest: ExternalTranslationBridge.shared.receive
      )
    )
  }()

  private let handler: HotkeySelectionCaptureMethodHandler
  private var channel: FlutterMethodChannel?

  init(handler: HotkeySelectionCaptureMethodHandler) {
    self.handler = handler
  }

  func attach(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.aitrans/hotkey_selection",
      binaryMessenger: binaryMessenger
    )
    self.channel = channel
    channel.setMethodCallHandler { [handler] call, result in
      do {
        result(try handler.handle(method: call.method, arguments: call.arguments))
      } catch HotkeySelectionCaptureMethodError.unsupportedMethod {
        result(FlutterMethodNotImplemented)
      } catch {
        result(
          FlutterError(
            code: "capture_failed",
            message: "Unable to read selected text.",
            details: nil
          )
        )
      }
    }
  }
}

final class MenuBarTranslationCoordinator {
  static let shared: MenuBarTranslationCoordinator = {
    let selectedTextReader = AccessibilitySelectedTextReader()
    let resolver = MenuBarTranslationTextResolver(
      readSelectedText: {
        selectedTextReader.readSelectedText(promptIfNeeded: true)
      },
      readClipboardText: {
        NSPasteboard.general.string(forType: .string)
      }
    )
    return MenuBarTranslationCoordinator(
      resolveText: resolver.resolve,
      requestFactory: .shared,
      openTranslation: {
        ApplicationCommandBridge.shared.send(.showTranslation)
      },
      onRequest: ExternalTranslationBridge.shared.receive
    )
  }()

  private let resolveText: () -> String?
  private let requestFactory: ExternalTranslationRequestFactory
  private let openTranslation: () -> Void
  private let onRequest: (NativeExternalTranslationRequest) -> Void

  init(
    resolveText: @escaping () -> String?,
    requestFactory: ExternalTranslationRequestFactory,
    openTranslation: @escaping () -> Void,
    onRequest: @escaping (NativeExternalTranslationRequest) -> Void
  ) {
    self.resolveText = resolveText
    self.requestFactory = requestFactory
    self.openTranslation = openTranslation
    self.onRequest = onRequest
  }

  func translate() {
    openTranslation()
    guard let text = resolveText() else { return }
    onRequest(requestFactory.makeRequest(text: text))
  }
}

enum ApplicationCommand: String, Equatable {
  case showTranslation
  case showSettings
}

final class ApplicationCommandBuffer {
  typealias Sender = (ApplicationCommand) -> Void

  private var sender: Sender?
  private(set) var pendingCommand: ApplicationCommand?

  func receive(_ command: ApplicationCommand) {
    guard let sender else {
      pendingCommand = command
      return
    }
    sender(command)
  }

  func attach(sender: @escaping Sender) {
    self.sender = sender
    guard let pendingCommand else { return }
    self.pendingCommand = nil
    sender(pendingCommand)
  }
}

final class ApplicationCommandBridge {
  static let shared = ApplicationCommandBridge()

  private let buffer = ApplicationCommandBuffer()
  private var channel: FlutterMethodChannel?

  func send(_ command: ApplicationCommand) {
    DispatchQueue.main.async {
      _ = MainWindowPresenter.shared.showMainWindow()
      self.buffer.receive(command)
    }
  }

  func attach(binaryMessenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.aitrans/application_commands",
      binaryMessenger: binaryMessenger
    )
    self.channel = channel
    channel.setMethodCallHandler { [weak self, weak channel] call, result in
      guard call.method == "ready" else {
        result(FlutterMethodNotImplemented)
        return
      }
      self?.buffer.attach { [weak channel] command in
        channel?.invokeMethod(
          "applicationCommand",
          arguments: ["command": command.rawValue]
        )
      }
      result(nil)
    }
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

enum NativeExternalTranslationSource: String, Equatable {
  case macosService
  case macosHotkey
}

struct NativeExternalTranslationRequest: Equatable {
  let sequence: Int64
  let source: NativeExternalTranslationSource
  let text: String

  init(
    sequence: Int64,
    source: NativeExternalTranslationSource = .macosService,
    text: String
  ) {
    self.sequence = sequence
    self.source = source
    self.text = text
  }
}

final class ExternalTranslationRequestFactory {
  static let shared = ExternalTranslationRequestFactory()

  private let lock = NSLock()
  private var sequence: Int64 = 0

  func makeRequest(
    text: String,
    source: NativeExternalTranslationSource = .macosService
  ) -> NativeExternalTranslationRequest {
    lock.lock()
    defer { lock.unlock() }
    precondition(sequence < Int64.max, "External translation sequence exhausted")
    sequence += 1
    return NativeExternalTranslationRequest(
      sequence: sequence,
      source: source,
      text: text
    )
  }
}

final class ExternalTranslationServiceProvider: NSObject {
  typealias RequestHandler = (NativeExternalTranslationRequest) -> Void

  private let onRequest: RequestHandler
  private let requestFactory: ExternalTranslationRequestFactory

  init(
    requestFactory: ExternalTranslationRequestFactory = ExternalTranslationRequestFactory(),
    onRequest: @escaping RequestHandler
  ) {
    self.requestFactory = requestFactory
    self.onRequest = onRequest
  }

  @objc func translateSelection(
    _ pasteboard: NSPasteboard,
    userData: String?,
    error errorPointer: AutoreleasingUnsafeMutablePointer<NSString?>?
  ) {
    do {
      let text = try ServicePasteboardParser.parse(pasteboard)
      onRequest(requestFactory.makeRequest(text: text))
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
            "source": request.source.rawValue,
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
  private lazy var translationServiceProvider = ExternalTranslationServiceProvider(
    requestFactory: .shared,
    onRequest: ExternalTranslationBridge.shared.receive
  )
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
