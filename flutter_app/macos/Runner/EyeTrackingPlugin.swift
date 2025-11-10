import Cocoa
import FlutterMacOS
import AVFoundation

public class EyeTrackingPlugin: NSObject, FlutterPlugin {
    private var trackingEngine: OpaquePointer?
    private var eventSink: FlutterEventSink?
    private var trackingTimer: Timer?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "eyeball_tracking/camera", binaryMessenger: registrar.messenger)
        let eventChannel = FlutterEventChannel(name: "eyeball_tracking/tracking", binaryMessenger: registrar.messenger)

        let instance = EyeTrackingPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initializeTrackingEngine":
            initializeTrackingEngine(result: result)
        case "startTracking":
            startTracking(result: result)
        case "stopTracking":
            stopTracking(result: result)
        case "processFrame":
            processFrame(call.arguments, result: result)
        case "setCameraParameters":
            setCameraParameters(call.arguments, result: result)
        case "startCalibration":
            startCalibration(result: result)
        case "addCalibrationPoint":
            addCalibrationPoint(call.arguments, result: result)
        case "finishCalibration":
            finishCalibration(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func initializeTrackingEngine(result: @escaping FlutterResult) {
        trackingEngine = create_tracking_engine()
        if trackingEngine != nil {
            let success = initialize_tracking_engine(trackingEngine)
            result(success)
        } else {
            result(FlutterError(code: "ENGINE_INIT_FAILED", message: "Failed to create tracking engine", details: nil))
        }
    }

    private func startTracking(result: @escaping FlutterResult) {
        // Start a timer to simulate tracking results
        // In a real implementation, this would process camera frames
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.sendTrackingResult()
        }
        result(true)
    }

    private func stopTracking(result: @escaping FlutterResult) {
        trackingTimer?.invalidate()
        trackingTimer = nil
        result(true)
    }

    private func processFrame(_ arguments: Any?, result: @escaping FlutterResult) {
        // For now, just return success
        // In a real implementation, this would process the frame data
        result(true)
    }

    private func setCameraParameters(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let focalLength = args["focalLength"] as? Double,
              let principalX = args["principalX"] as? Double,
              let principalY = args["principalY"] as? Double else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid camera parameters", details: nil))
            return
        }

        if trackingEngine != nil {
            set_camera_parameters(trackingEngine, focalLength, principalX, principalY)
        }
        result(true)
    }

    private func startCalibration(result: @escaping FlutterResult) {
        // For now, just return success
        result(true)
    }

    private func addCalibrationPoint(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              let x = args["x"] as? Double,
              let y = args["y"] as? Double else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid calibration point", details: nil))
            return
        }

        // For now, just return success
        result(true)
    }

    private func finishCalibration(result: @escaping FlutterResult) {
        // For now, just return success
        result(true)
    }

    private func sendTrackingResult() {
        // Generate mock tracking data for now
        let timestamp = Date().timeIntervalSince1970
        let mockResult: [String: Any] = [
            "faceDistance": Double.random(in: 30...80),
            "gazeAngleX": Double.random(in: -0.5...0.5),
            "gazeAngleY": Double.random(in: -0.5...0.5),
            "eyesFocused": Bool.random(),
            "headMoving": Bool.random(),
            "shouldersMoving": Bool.random()
        ]

        eventSink?(mockResult)
    }
}

extension EyeTrackingPlugin: FlutterStreamHandler {
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        eventSink = nil
        return nil
    }
}
