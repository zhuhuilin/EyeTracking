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

    // Register main camera tracking channel with stub implementations
    let trackingRegistrar = flutterViewController.registrar(forPlugin: "CameraTracking")
    let trackingChannel = FlutterMethodChannel(
      name: "eyeball_tracking/camera",
      binaryMessenger: trackingRegistrar.messenger
    )

    trackingChannel.setMethodCallHandler { (call, result) in
      switch call.method {
      case "initializeTrackingEngine":
        // Stub: tracking engine initialization
        print("Native: initializeTrackingEngine called")
        result(nil)
      case "startTracking":
        // Stub: start tracking
        print("Native: startTracking called")
        result(nil)
      case "stopTracking":
        // Stub: stop tracking
        print("Native: stopTracking called")
        result(nil)
      case "processFrame":
        // Stub: process frame
        // In a real implementation, this would process camera frames
        result(nil)
      case "setCameraParameters":
        // Stub: set camera parameters
        if let args = call.arguments as? [String: Any] {
          print("Native: setCameraParameters - \(args)")
        }
        result(nil)
      case "startCalibration":
        // Stub: start calibration
        print("Native: startCalibration called")
        result(nil)
      case "addCalibrationPoint":
        // Stub: add calibration point
        if let args = call.arguments as? [String: Any] {
          print("Native: addCalibrationPoint - x: \(args["x"] ?? 0), y: \(args["y"] ?? 0)")
        }
        result(nil)
      case "finishCalibration":
        // Stub: finish calibration
        print("Native: finishCalibration called")
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    super.awakeFromNib()
  }
}
