import UIKit
import Flutter
import ReplayKit
import CoreImage
import CoreMedia

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private let channelName = "atlas.one/native"
  private var latestFrame: String?
  private var captureActive = false
  private var lastFrameAt = Date.distantPast

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AtlasNativeBridge") else {
      return
    }

    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: registrar.messenger()
    )

    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(FlutterError(code: "DEALLOCATED", message: "Atlas bridge unavailable", details: nil))
        return
      }
      switch call.method {
      case "startScreenVision":
        self.startScreenCapture(result: result)
      case "stopScreenVision":
        self.stopScreenCapture(result: result)
      case "captureScreenFrame":
        result(self.latestFrame)
      case "listApps":
        result(self.supportedApps())
      case "launchApp":
        let args = call.arguments as? [String: Any]
        self.launchSupportedApp(id: args?["id"] as? String, result: result)
      case "revokeSensitivePermissions":
        self.stopScreenCapture(result: nil)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func startScreenCapture(result: @escaping FlutterResult) {
    guard !captureActive else {
      result(true)
      return
    }

    let recorder = RPScreenRecorder.shared()
    recorder.isMicrophoneEnabled = false
    recorder.startCapture(
      handler: { [weak self] buffer, type, error in
        guard error == nil, type == .video, let self = self else { return }
        let now = Date()
        guard now.timeIntervalSince(self.lastFrameAt) > 0.7 else { return }
        self.lastFrameAt = now

        guard let imageBuffer = CMSampleBufferGetImageBuffer(buffer) else { return }
        let ci = CIImage(cvPixelBuffer: imageBuffer)
        let context = CIContext(options: nil)
        guard let cg = context.createCGImage(ci, from: ci.extent) else { return }
        let image = UIImage(cgImage: cg)
        if let data = image.jpegData(compressionQuality: 0.62) {
          self.latestFrame = data.base64EncodedString()
        }
      },
      completionHandler: { [weak self] error in
        DispatchQueue.main.async {
          if let error = error {
            result(
              FlutterError(
                code: "SCREEN_CAPTURE",
                message: error.localizedDescription,
                details: nil
              )
            )
          } else {
            self?.captureActive = true
            result(true)
          }
        }
      }
    )
  }

  private func stopScreenCapture(result: FlutterResult?) {
    guard captureActive else {
      latestFrame = nil
      result?(nil)
      return
    }

    RPScreenRecorder.shared().stopCapture { [weak self] _ in
      self?.captureActive = false
      self?.latestFrame = nil
      DispatchQueue.main.async { result?(nil) }
    }
  }

  // iOS intentionally exposes documented system integrations only. A normal
  // third-party app cannot enumerate or arbitrarily control every installed app.
  private func supportedApps() -> [[String: String]] {
    return [
      ["id": "https://www.google.com", "name": "Browser"],
      ["id": "mailto:", "name": "Mail"],
      ["id": "tel:", "name": "Phone"],
      ["id": "sms:", "name": "Messages"],
      ["id": "https://maps.apple.com", "name": "Maps"]
    ]
  }

  private func launchSupportedApp(id: String?, result: @escaping FlutterResult) {
    guard let id = id, let url = URL(string: id) else {
      result(false)
      return
    }
    UIApplication.shared.open(url, options: [:]) { ok in
      result(ok)
    }
  }
}
