import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let scannerBrightnessChannel = "com.hiltking.app/scanner_brightness"
  private var previousScreenBrightness: CGFloat?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: scannerBrightnessChannel,
        binaryMessenger: controller.binaryMessenger
      )

      channel.setMethodCallHandler { [weak self] call, result in
        guard let self else {
          result(FlutterError(code: "scanner_unavailable", message: "App delegate unavailable", details: nil))
          return
        }

        switch call.method {
        case "dimForScanner":
          let args = call.arguments as? [String: Any]
          let level = (args?["level"] as? Double) ?? 0.08
          self.dimForScanner(level: CGFloat(level))
          result(nil)
        case "restoreBrightness":
          self.restoreBrightness()
          result(nil)
        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }

  private func dimForScanner(level: CGFloat) {
    if previousScreenBrightness == nil {
      previousScreenBrightness = UIScreen.main.brightness
    }

    UIScreen.main.brightness = min(max(level, 0.01), 0.2)
  }

  private func restoreBrightness() {
    UIScreen.main.brightness = previousScreenBrightness ?? UIScreen.main.brightness
    previousScreenBrightness = nil
  }
}
