import Cocoa
import FlutterMacOS
import XCTest
@testable import aitrans

class RunnerTests: XCTestCase {

  func testAppDelegateKeepsRunningAfterLastWindowCloses() {
    let delegate = AppDelegate()

    XCTAssertFalse(delegate.applicationShouldTerminateAfterLastWindowClosed(NSApp))
  }

  func testApplicationLifecycleControllerReopensTheExistingWindowFromDock() {
    var presentationCount = 0
    let controller = ApplicationLifecycleController(
      showMainWindow: {
        presentationCount += 1
        return true
      }
    )

    XCTAssertFalse(controller.handleDockReopen())
    XCTAssertEqual(presentationCount, 1)
  }

  func testMenuBarPreferenceMethodHandlerGetsAndSetsTypedVisibility() throws {
    var appliedValues: [Bool] = []
    var visibility = true
    let handler = MenuBarPreferenceMethodHandler(
      getVisibility: { visibility },
      setVisibility: {
        visibility = $0
        appliedValues.append($0)
      }
    )

    XCTAssertEqual(
      try handler.handle(method: "getVisibility", arguments: nil) as? Bool,
      true
    )
    XCTAssertEqual(
      try handler.handle(method: "setVisibility", arguments: false) as? Bool,
      false
    )
    XCTAssertEqual(appliedValues, [false])
  }

  func testMenuBarPreferenceMethodHandlerRejectsInvalidCalls() {
    let handler = MenuBarPreferenceMethodHandler(
      getVisibility: { true },
      setVisibility: { _ in }
    )

    XCTAssertThrowsError(
      try handler.handle(method: "setVisibility", arguments: "false")
    ) { error in
      XCTAssertEqual(error as? MenuBarPreferenceMethodError, .invalidVisibility)
    }
    XCTAssertThrowsError(
      try handler.handle(method: "unknown", arguments: nil)
    ) { error in
      XCTAssertEqual(error as? MenuBarPreferenceMethodError, .unsupportedMethod)
    }
  }

  func testMenuBarVisibilityDefaultsToVisibleAndPersistsExplicitChoice() {
    let suiteName = "test.menu-bar-preferences.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let preferences = MenuBarVisibilityPreferences(defaults: defaults)

    XCTAssertTrue(preferences.isVisible)

    preferences.isVisible = false

    XCTAssertFalse(MenuBarVisibilityPreferences(defaults: defaults).isVisible)
  }

  func testBundleContainsTheMenuBarTemplateIcon() {
    XCTAssertNotNil(NSImage(named: NSImage.Name("MenuBarIcon")))
  }

  func testMenuBarStatusControllerAppliesStoredPreferenceIdempotentlyAndTogglesWindow() {
    let suiteName = "test.menu-bar-controller.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let preferences = MenuBarVisibilityPreferences(defaults: defaults)
    var createdItems: [FakeMenuBarStatusItem] = []
    var toggleCount = 0
    var menuCommands: [MenuBarCommand] = []
    let controller = MenuBarStatusController(
      preferences: preferences,
      makeStatusItem: {
        let item = FakeMenuBarStatusItem()
        createdItems.append(item)
        return item
      },
      imageLoader: { nil },
      onToggleMainWindow: { toggleCount += 1 },
      onTranslate: { menuCommands.append(.translate) },
      onOpenSettings: { menuCommands.append(.settings) },
      onQuit: { menuCommands.append(.quit) }
    )

    controller.applyStoredPreference()
    controller.setVisible(true)

    XCTAssertTrue(controller.isVisible)
    XCTAssertEqual(createdItems.count, 1)
    XCTAssertEqual(createdItems[0].title, "A")
    XCTAssertEqual(createdItems[0].toolTip, "显示或关闭 AITrans")

    XCTAssertEqual(createdItems[0].menuCommands, MenuBarCommand.allCases)

    createdItems[0].triggerPrimaryClick()
    XCTAssertEqual(toggleCount, 1)

    createdItems[0].triggerMenuCommand(.translate)
    createdItems[0].triggerMenuCommand(.settings)
    createdItems[0].triggerMenuCommand(.quit)
    XCTAssertEqual(menuCommands, [.translate, .settings, .quit])

    controller.setVisible(false)
    controller.setVisible(false)

    XCTAssertFalse(controller.isVisible)
    XCTAssertTrue(createdItems[0].wasRemoved)
    XCTAssertFalse(preferences.isVisible)
  }

  func testMenuBarCommandsExposeTheRequiredLocalizedTitlesInOrder() {
    XCTAssertEqual(MenuBarCommand.allCases, [.translate, .settings, .quit])
    XCTAssertEqual(MenuBarCommand.allCases.map(\.title), ["翻译", "设置", "退出"])
  }

  func testMenuBarPresentationUsesTheRequestedWidthAndSeparatesQuit() {
    XCTAssertEqual(MenuBarMenuPresentation.minimumWidth, 180)
    XCTAssertEqual(
      MenuBarMenuPresentation.elements,
      [.command(.translate), .command(.settings), .separator, .command(.quit)]
    )
  }

  func testTranslateMenuCommandUsesADedicatedShortcutAndSemanticIcon() {
    XCTAssertEqual(MenuBarCommand.translate.keyEquivalent, "t")
    XCTAssertEqual(
      MenuBarCommand.translate.keyEquivalentModifierMask,
      [.command]
    )
    XCTAssertEqual(MenuBarCommand.translate.systemImageName, "character.bubble")
    XCTAssertEqual(MenuBarCommand.settings.systemImageName, "gearshape")
    XCTAssertEqual(MenuBarCommand.quit.systemImageName, "power")
  }

  func testMenuBarTranslationTextResolverPrefersSelectionThenFallsBackToClipboard() {
    var selectedText: String? = " selected text "
    var clipboardReadCount = 0
    let resolver = MenuBarTranslationTextResolver(
      readSelectedText: { selectedText },
      readClipboardText: {
        clipboardReadCount += 1
        return " clipboard text "
      }
    )

    XCTAssertEqual(resolver.resolve(), "selected text")
    XCTAssertEqual(clipboardReadCount, 0)

    selectedText = "  \n"
    XCTAssertEqual(resolver.resolve(), "clipboard text")
    XCTAssertEqual(clipboardReadCount, 1)
  }

  func testHotkeySelectionCaptureMethodForwardsResolvedText() throws {
    var requests: [NativeExternalTranslationRequest] = []
    let requestFactory = ExternalTranslationRequestFactory()
    let handler = HotkeySelectionCaptureMethodHandler(
      resolveText: { "selected by hotkey" },
      requestFactory: requestFactory,
      onRequest: { requests.append($0) }
    )

    XCTAssertEqual(
      try handler.handle(method: "captureSelection", arguments: nil) as? Bool,
      true
    )
    XCTAssertEqual(requests.map(\.text), ["selected by hotkey"])
    XCTAssertEqual(requests.map(\.source), [.macosHotkey])
  }

  func testHotkeySelectionCaptureMethodReturnsFalseWithoutReadableText() throws {
    var requestCount = 0
    let handler = HotkeySelectionCaptureMethodHandler(
      resolveText: { nil },
      requestFactory: ExternalTranslationRequestFactory(),
      onRequest: { _ in requestCount += 1 }
    )

    XCTAssertEqual(
      try handler.handle(method: "captureSelection", arguments: nil) as? Bool,
      false
    )
    XCTAssertEqual(requestCount, 0)
  }

  func testMenuBarTranslationCoordinatorAlwaysOpensTranslationAndForwardsResolvedText() {
    let requestFactory = ExternalTranslationRequestFactory()
    var openCount = 0
    var requests: [NativeExternalTranslationRequest] = []
    var resolvedText: String? = "selected text"
    let coordinator = MenuBarTranslationCoordinator(
      resolveText: { resolvedText },
      requestFactory: requestFactory,
      openTranslation: { openCount += 1 },
      onRequest: { requests.append($0) }
    )

    coordinator.translate()
    resolvedText = nil
    coordinator.translate()

    XCTAssertEqual(openCount, 2)
    XCTAssertEqual(requests, [
      NativeExternalTranslationRequest(sequence: 1, text: "selected text")
    ])
  }

  func testSharedRequestFactoryKeepsServiceAndMenuRequestsMonotonic() {
    let requestFactory = ExternalTranslationRequestFactory()
    var requests: [NativeExternalTranslationRequest] = []
    let service = ExternalTranslationServiceProvider(
      requestFactory: requestFactory,
      onRequest: { requests.append($0) }
    )
    let menu = MenuBarTranslationCoordinator(
      resolveText: { "clipboard text" },
      requestFactory: requestFactory,
      openTranslation: {},
      onRequest: { requests.append($0) }
    )

    service.translateSelection(makePasteboard(text: "selection"), userData: nil, error: nil)
    menu.translate()

    XCTAssertEqual(requests.map(\.sequence), [1, 2])
    XCTAssertEqual(requests.map(\.text), ["selection", "clipboard text"])
  }

  func testApplicationCommandBufferKeepsLatestColdCommandAndDeliversWarmCommands() {
    let buffer = ApplicationCommandBuffer()
    var delivered: [ApplicationCommand] = []

    buffer.receive(.showTranslation)
    buffer.receive(.showSettings)
    buffer.attach { delivered.append($0) }
    buffer.receive(.showTranslation)

    XCTAssertEqual(delivered, [.showSettings, .showTranslation])
  }

  func testMainWindowPresenterRestoresTheExistingMinimizedWindow() {
    let window = FakeMainWindow(isMiniaturized: true)
    var activationCount = 0
    let presenter = MainWindowPresenter(
      windowProvider: { window },
      activateApplication: { activationCount += 1 }
    )

    XCTAssertTrue(presenter.showMainWindow())

    XCTAssertFalse(window.isMiniaturized)
    XCTAssertTrue(window.isVisible)
    XCTAssertTrue(window.isKey)
    XCTAssertEqual(activationCount, 1)
  }

  func testMainWindowPresenterTogglesVisibleWindowClosedThenOpen() {
    let window = FakeMainWindow(isMiniaturized: false, isVisible: true)
    var activationCount = 0
    let presenter = MainWindowPresenter(
      windowProvider: { window },
      activateApplication: { activationCount += 1 }
    )

    XCTAssertFalse(presenter.toggleMainWindow())
    XCTAssertFalse(window.isVisible)
    XCTAssertFalse(window.isKey)
    XCTAssertEqual(activationCount, 0)

    XCTAssertTrue(presenter.toggleMainWindow())
    XCTAssertTrue(window.isVisible)
    XCTAssertTrue(window.isKey)
    XCTAssertEqual(activationCount, 1)
  }

  func testMainWindowPresenterShowsNonKeyWindowWhenVisibilityIsStale() {
    let window = FakeMainWindow(
      isMiniaturized: false,
      isVisible: true,
      isKey: false
    )
    var activationCount = 0
    let presenter = MainWindowPresenter(
      windowProvider: { window },
      activateApplication: { activationCount += 1 }
    )

    XCTAssertTrue(presenter.toggleMainWindow())
    XCTAssertTrue(window.isVisible)
    XCTAssertTrue(window.isKey)
    XCTAssertEqual(activationCount, 1)
  }

  func testMainWindowRegistryKeepsClosedWindowAvailableForToggleReopen() {
    let registry = MainWindowRegistry()
    let window = FakeMainWindow(isMiniaturized: false, isVisible: true)
    registry.register(window)
    let presenter = MainWindowPresenter(
      windowProvider: { registry.mainWindow },
      activateApplication: {}
    )

    XCTAssertFalse(presenter.toggleMainWindow())
    XCTAssertTrue(registry.mainWindow === window)
    XCTAssertTrue(presenter.toggleMainWindow())
    XCTAssertTrue(window.isVisible)
  }

  func testMainWindowPresenterReportsMissingWindowWithoutActivating() {
    var activationCount = 0
    let presenter = MainWindowPresenter(
      windowProvider: { nil },
      activateApplication: { activationCount += 1 }
    )

    XCTAssertFalse(presenter.showMainWindow())
    XCTAssertEqual(activationCount, 0)
  }

  func testBundleDeclaresHostCompatibleTextService() throws {
    let services = try XCTUnwrap(
      Bundle.main.object(forInfoDictionaryKey: "NSServices") as? [[String: Any]]
    )
    let service = try XCTUnwrap(services.first)
    let menuItem = try XCTUnwrap(service["NSMenuItem"] as? [String: String])

    XCTAssertEqual(services.count, 1)
    XCTAssertEqual(menuItem["default"], "使用 AITrans 翻译")
    XCTAssertEqual(service["NSMessage"] as? String, "translateSelection")
    XCTAssertEqual(
      service["NSSendTypes"] as? [String],
      ["NSStringPboardType", "public.utf8-plain-text"]
    )
  }

  func testServiceParserAcceptsExactlyOnePlainTextItem() throws {
    let pasteboard = NSPasteboard(name: .init("test.valid.\(UUID().uuidString)"))
    pasteboard.clearContents()
    pasteboard.writeObjects(["selected text" as NSString])

    let text = try ServicePasteboardParser.parse(pasteboard)

    XCTAssertEqual(text, "selected text")
  }

  func testServiceParserRejectsMissingPlainText() {
    let pasteboard = NSPasteboard(name: .init("test.missing.\(UUID().uuidString)"))
    pasteboard.clearContents()
    let item = NSPasteboardItem()
    item.setData(Data([0x01]), forType: .init("com.aitrans.unsupported"))
    pasteboard.writeObjects([item])

    XCTAssertThrowsError(try ServicePasteboardParser.parse(pasteboard)) { error in
      XCTAssertEqual(error as? ServiceRequestError, .plainTextUnavailable)
      XCTAssertFalse(error.localizedDescription.contains("selected"))
    }
  }

  func testServiceParserRejectsMultipleItems() {
    let pasteboard = NSPasteboard(name: .init("test.multiple.\(UUID().uuidString)"))
    pasteboard.clearContents()
    pasteboard.writeObjects(["first" as NSString, "second" as NSString])

    XCTAssertThrowsError(try ServicePasteboardParser.parse(pasteboard)) { error in
      XCTAssertEqual(error as? ServiceRequestError, .invalidItemCount)
    }
  }

  func testServiceProviderAssignsMonotonicSequenceAndForwardsText() {
    var requests: [NativeExternalTranslationRequest] = []
    let provider = ExternalTranslationServiceProvider { requests.append($0) }

    provider.translateSelection(makePasteboard(text: "first"), userData: nil, error: nil)
    provider.translateSelection(makePasteboard(text: "second"), userData: nil, error: nil)

    XCTAssertEqual(requests.map(\.sequence), [1, 2])
    XCTAssertEqual(requests.map(\.text), ["first", "second"])
  }

  func testServiceProviderReturnsSafeErrorWithoutForwardingInvalidPayload() {
    var requests: [NativeExternalTranslationRequest] = []
    let provider = ExternalTranslationServiceProvider { requests.append($0) }
    let pasteboard = NSPasteboard(name: .init("test.invalid.\(UUID().uuidString)"))
    pasteboard.clearContents()
    var message: NSString?

    provider.translateSelection(pasteboard, userData: nil, error: &message)

    XCTAssertTrue(requests.isEmpty)
    XCTAssertEqual(message, "AITrans 只能处理单段纯文本。")
  }

  func testServiceRegistrationInstallsProviderAndRefreshesDynamicServicesOnlyOnce() {
    var installedProviders: [NSObject] = []
    var refreshCount = 0
    let registration = MacOSServiceRegistration(
      setServicesProvider: { installedProviders.append($0) },
      refreshDynamicServices: { refreshCount += 1 }
    )
    let provider = NSObject()

    registration.ensureRegistered(provider: provider)
    registration.ensureRegistered(provider: provider)

    XCTAssertEqual(installedProviders.count, 1)
    XCTAssertTrue(installedProviders.first === provider)
    XCTAssertEqual(refreshCount, 1)
  }

  func testRequestBufferKeepsOnlyLatestRequestBeforeFlutterAttaches() {
    let buffer = ExternalTranslationRequestBuffer()
    let first = NativeExternalTranslationRequest(sequence: 1, text: "first")
    let second = NativeExternalTranslationRequest(sequence: 2, text: "second")
    var delivered: [NativeExternalTranslationRequest] = []

    buffer.receive(first)
    buffer.receive(second)
    buffer.attach { delivered.append($0) }

    XCTAssertEqual(delivered, [second])
    XCTAssertNil(buffer.pendingRequest)
  }

  func testRequestBufferDeliversWarmRequestsImmediately() {
    let buffer = ExternalTranslationRequestBuffer()
    var delivered: [NativeExternalTranslationRequest] = []
    buffer.attach { delivered.append($0) }

    buffer.receive(NativeExternalTranslationRequest(sequence: 1, text: "first"))
    buffer.receive(NativeExternalTranslationRequest(sequence: 2, text: "second"))

    XCTAssertEqual(delivered.map(\.sequence), [1, 2])
  }

  private func makePasteboard(text: String) -> NSPasteboard {
    let pasteboard = NSPasteboard(name: .init("test.service.\(UUID().uuidString)"))
    pasteboard.clearContents()
    pasteboard.writeObjects([text as NSString])
    return pasteboard
  }

}

private final class FakeMenuBarStatusItem: MenuBarStatusItem {
  private(set) var image: NSImage?
  private(set) var title = ""
  private(set) var toolTip: String?
  private(set) var wasRemoved = false
  private var onPrimaryClick: (() -> Void)?
  private var onMenuCommand: ((MenuBarCommand) -> Void)?
  private(set) var menuCommands: [MenuBarCommand] = []

  func configure(
    image: NSImage?,
    fallbackTitle: String,
    toolTip: String,
    onPrimaryClick: @escaping () -> Void,
    onMenuCommand: @escaping (MenuBarCommand) -> Void
  ) {
    self.image = image
    title = image == nil ? fallbackTitle : ""
    self.toolTip = toolTip
    self.onPrimaryClick = onPrimaryClick
    self.onMenuCommand = onMenuCommand
    menuCommands = MenuBarCommand.allCases
  }

  func remove() {
    wasRemoved = true
  }

  func triggerPrimaryClick() {
    guard let onPrimaryClick else {
      XCTFail("Status item action was not configured.")
      return
    }
    onPrimaryClick()
  }

  func triggerMenuCommand(_ command: MenuBarCommand) {
    guard let onMenuCommand else {
      XCTFail("Status item menu action was not configured.")
      return
    }
    onMenuCommand(command)
  }
}

private final class FakeMainWindow: MainWindowPresentable {
  var isMiniaturized: Bool
  private(set) var isVisible: Bool
  private(set) var isKey = false

  var isKeyWindow: Bool { isKey }

  init(
    isMiniaturized: Bool,
    isVisible: Bool = false,
    isKey: Bool? = nil
  ) {
    self.isMiniaturized = isMiniaturized
    self.isVisible = isVisible
    self.isKey = isKey ?? isVisible
  }

  func deminiaturize(_ sender: Any?) {
    isMiniaturized = false
  }

  func makeKeyAndOrderFront(_ sender: Any?) {
    isVisible = true
    isKey = true
  }

  func close() {
    isVisible = false
    isKey = false
  }
}
