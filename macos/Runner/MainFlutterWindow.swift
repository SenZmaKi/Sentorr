import Cocoa
import FlutterMacOS
import ServiceManagement

class MainFlutterWindow: NSWindow {
  private var startupReady = false
  private var sparkleUpdateBridge: SparkleUpdateBridge?

  override func awakeFromNib() {
    // Apply the saved brand before starting Flutter and its asynchronous bootstrap.
    let launchBackground = applyLaunchAppearance()
    let flutterViewController = RestartSafeFlutterViewController()
    flutterViewController.backgroundColor = launchBackground
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    FlutterMethodChannel(
      name: "sentorr/startup", binaryMessenger: flutterViewController.engine.binaryMessenger
    ).setMethodCallHandler { [weak self] call, result in
      guard let self else { result(false); return }
      guard call.method == "readyToShow" else {
        result(FlutterMethodNotImplemented)
        return
      }
      #if DEBUG
      // Exercise real startup/rasterization without displaying or activating a
      // window during the native smoke check.
      if ProcessInfo.processInfo.environment["SENTORR_STARTUP_SMOKE"] == "1" {
        let white = self.backgroundColor?.usingColorSpace(.genericGray)?.whiteComponent ?? -1
        NSLog("SENTORR_STARTUP_READY visible=\(self.isVisible) white=\(white)")
        result(false)
        return
      }
      #endif
      self.startupReady = true
      result(true)
    }

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
    #if DEBUG
    terminationChannel.setMethodCallHandler { call, result in
      guard call.method == "probeQuit" else {
        result(FlutterMethodNotImplemented)
        return
      }
      result(nil)
      NSApp.terminate(nil)
    }
    #endif

    let windowReopenChannel = FlutterMethodChannel(
      name: "sentorr/window_reopen", binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    (NSApp.delegate as? AppDelegate)?.setWindowReopenChannel(windowReopenChannel)

    // Flutter keeps the running Dock icon in sync with later theme changes.
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
    // Flutter normally runs from viewWillAppear. Our window stays hidden until
    // its first app frame is ready, so start the engine without ordering it in.
    flutterViewController.engine.run(withEntrypoint: nil)

    super.awakeFromNib()
  }

  private func applyLaunchAppearance() -> NSColor {
    guard let support = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first, let bundleID = Bundle.main.bundleIdentifier else { return .windowBackgroundColor }
    let directory = bundleID.hasSuffix(".nightly") ? "SentorrNightlyData" : "SentorrData"
    let settings = support.appendingPathComponent(bundleID)
      .appendingPathComponent(directory).appendingPathComponent("settings/settings.json")
    let mode = Self.savedThemeMode(at: settings)
    let systemDark = NSApp.effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
    let light = mode == "light" || (mode == "system" && !systemDark)
    let background: NSColor = light ? .white : .black
    backgroundColor = background
    guard let frameworks = Bundle.main.privateFrameworksURL else { return background }
    let asset = frameworks.appendingPathComponent(
      "App.framework/Resources/flutter_assets/assets/images/dock-\(light ? "light" : "dark").png"
    )
    if let icon = NSImage(contentsOf: asset) {
      NSApp.applicationIconImage = icon
    }
    return background
  }

  static func savedThemeMode(at url: URL) -> String {
    // Match Dart's backup recovery without modifying its settings files.
    for candidate in [url, URL(fileURLWithPath: url.path + ".bak")] {
      if let data = try? Data(contentsOf: candidate),
         let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] {
        let mode = json["themeMode"] as? String ?? "system"
        return ["light", "dark", "system"].contains(mode) ? mode : "system"
      }
    }
    return "system"
  }

  // Nib loading, activation and fullscreen restoration must not expose the
  // Flutter surface before Dart confirms that its app frame was rasterized.
  override public func order(_ place: NSWindow.OrderingMode, relativeTo otherWin: Int) {
    guard startupReady || place == .out else { return }
    super.order(place, relativeTo: otherWin)
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
