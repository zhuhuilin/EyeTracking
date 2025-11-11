import Cocoa
import FlutterMacOS
import AVFoundation

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    // Manually register the custom native plugin that powers the tracking channel
    let eyeTrackingRegistrar = flutterViewController.registrar(forPlugin: "EyeTrackingPlugin")
    EyeTrackingPlugin.register(with: eyeTrackingRegistrar)

    // Register custom camera helper method channel
    let helperRegistrar = flutterViewController.registrar(forPlugin: "CameraHelper")
    let helperChannel = FlutterMethodChannel(
      name: "eyeball_tracking/camera_helper",
      binaryMessenger: helperRegistrar.messenger
    )

    helperChannel.setMethodCallHandler { (call, result) in
      if call.method == "listCameras" {
        var devices: [AVCaptureDevice] = []

        if #available(macOS 10.15, *) {
          // Use modern DiscoverySession API for macOS 10.15+
          let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [
              .builtInWideAngleCamera,
              .externalUnknown
            ],
            mediaType: .video,
            position: .unspecified
          )
          devices = discoverySession.devices
        }

        var devicesList: [[String: Any]] = []
        for device in devices {
          devicesList.append([
            "deviceType": 0, // video
            "localizedName": device.localizedName,
            "manufacturer": device.manufacturer,
            "deviceId": device.uniqueID
          ])
        }

        result(["devices": devicesList])
      } else {
        result(FlutterMethodNotImplemented)
      }
    }

    // EyeTrackingPlugin will handle the camera tracking channel
    // Plugin registration happens in the Swift plugin itself

    super.awakeFromNib()
  }
}
