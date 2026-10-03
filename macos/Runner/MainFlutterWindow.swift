import Cocoa
import FlutterMacOS
import ServiceManagement

class MainFlutterWindow: NSWindow {
  private var sparkleUpdateBridge: SparkleUpdateBridge?

  override func awakeFromNib() {
    let flutterViewController = RestartSafeFlutterViewController()
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

    let sparkle = SparkleUpdateBridge()
    sparkle.register(with: flutterViewController.engine.binaryMessenger)
    self.sparkleUpdateBridge = sparkle

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }

  // Keep the window hidden until Dart has applied saved window preferences.
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    super.order(place, relativeTo: otherWin)
    hiddenWindowAtLaunch()
  }
}

// mpv survives Dart hot restart and can wake its deleted NativeCallable even
// before media_kit initializes again. Clear it at the native engine boundary.
private class RestartSafeFlutterViewController: FlutterViewController {
  private var playerHandles = Set<Int64>()
  private var restartChannel: FlutterMethodChannel?
  private typealias ClearWakeup = @convention(c) (
    UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?
  ) -> Void

  override func viewDidLoad() {
    super.viewDidLoad()
    let channel = FlutterMethodChannel(
      name: "sentorr/player_hot_restart", binaryMessenger: engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let handle = call.arguments as? Int64, handle != 0 else {
        result(FlutterError(code: "invalid_handle", message: "Expected mpv handle", details: nil))
        return
      }
      switch call.method {
      case "register": self?.playerHandles.insert(handle)
      case "unregister": self?.playerHandles.remove(handle)
      default:
        result(FlutterMethodNotImplemented)
        return
      }
      result(nil)
    }
    restartChannel = channel
  }

  override func onPreEngineRestart() {
    if !playerHandles.isEmpty {
      let path = Bundle.main.privateFrameworksPath! + "/Mpv.framework/Mpv"
      if let library = dlopen(path, RTLD_NOW) {
        if let symbol = dlsym(library, "mpv_set_wakeup_callback") {
          let clear = unsafeBitCast(symbol, to: ClearWakeup.self)
          for handle in playerHandles {
            clear(UnsafeMutableRawPointer(bitPattern: Int(handle)), nil, nil)
          }
        }
        dlclose(library)
      }
      playerHandles.removeAll()
    }
    super.onPreEngineRestart()
  }
}
