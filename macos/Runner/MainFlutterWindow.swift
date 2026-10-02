import Cocoa
import FlutterMacOS
import ServiceManagement

class MainFlutterWindow: NSWindow {

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    FlutterMethodChannel(
      name: "launch_at_startup", binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    .setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      switch call.method {
      case "launchAtStartupIsEnabled":
        if #available(macOS 13.0, *) {
          result(SMAppService.mainApp.status == .enabled)
        } else {
          result(false)
        }
      case "launchAtStartupSetEnabled":
        guard let arguments = call.arguments as? [String: Any],
              let isEnabled = arguments["setEnabledValue"] as? Bool else {
          result(FlutterError(code: "invalid_arguments", message: "Expected a startup enabled value.", details: nil))
          return
        }
        if #available(macOS 13.0, *) {
          do {
            if isEnabled {
              if SMAppService.mainApp.status != .enabled { try SMAppService.mainApp.register() }
            } else if SMAppService.mainApp.status == .enabled {
              try SMAppService.mainApp.unregister()
            }
            result(nil)
          } catch {
            result(FlutterError(code: "startup_unavailable", message: error.localizedDescription, details: nil))
          }
        } else if isEnabled {
          result(FlutterError(code: "unsupported", message: "Launch at login requires macOS 13 or later.", details: nil))
        } else {
          result(nil)
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let terminationChannel = FlutterMethodChannel(
      name: "sentorr/app_termination", binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    (NSApp.delegate as? AppDelegate)?.setTerminationChannel(terminationChannel)

    let windowReopenChannel = FlutterMethodChannel(
      name: "sentorr/window_reopen", binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    (NSApp.delegate as? AppDelegate)?.setWindowReopenChannel(windowReopenChannel)

    // Theme-driven running Dock icon. The bundle's launcher remains dark.
    FlutterMethodChannel(
      name: "sentorr/app_icon", binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    .setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard call.method == "setIcon" else {
        result(FlutterMethodNotImplemented)
        return
      }
      guard let bytes = call.arguments as? FlutterStandardTypedData,
            let icon = NSImage(data: bytes.data) else {
        result(FlutterError(code: "invalid_icon", message: "Expected PNG icon data.", details: nil))
        return
      }
      NSApp.applicationIconImage = icon
      result(nil)
    }

    FlutterMethodChannel(
      name: "sentorr/menu_bar_mode", binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    .setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard call.method == "setEnabled",
            let arguments = call.arguments as? [String: Any],
            let enabled = arguments["enabled"] as? Bool else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(NSApp.setActivationPolicy(enabled ? .accessory : .regular))
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  // Keep the window hidden until Dart has applied saved window preferences.
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}
