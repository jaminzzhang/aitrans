import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    MainWindowRegistry.shared.register(self)
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    ExternalTranslationBridge.shared.attach(
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    HotkeySelectionCaptureBridge.shared.attach(
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    ApplicationCommandBridge.shared.attach(
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    MenuBarPreferenceBridge.shared.attach(
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )

    super.awakeFromNib()
  }
}
