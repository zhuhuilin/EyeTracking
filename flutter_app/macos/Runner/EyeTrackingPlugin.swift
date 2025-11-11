import Cocoa
import FlutterMacOS
import AVFoundation

public class EyeTrackingPlugin: NSObject, FlutterPlugin {
    private var trackingEngine: UnsafeMutableRawPointer?
    private var eventSink: FlutterEventSink?
    private var savedWindowFrame: NSRect?
    private var wasFullscreen = false

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: "eyeball_tracking/camera",
            binaryMessenger: registrar.messenger
        )
        let eventChannel = FlutterEventChannel(
            name: "eyeball_tracking/tracking",
            binaryMessenger: registrar.messenger
        )

        let instance = EyeTrackingPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
        eventChannel.setStreamHandler(instance)
    }

    deinit {
        cleanupTrackingEngine()
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
        case "enterFullscreen":
            enterFullscreen(result: result)
        case "exitFullscreen":
            exitFullscreen(result: result)
        case "saveWindowState":
            saveWindowState(result: result)
        case "restoreWindowState":
            restoreWindowState(result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func cleanupTrackingEngine() {
        if let engine = trackingEngine {
            destroy_tracking_engine(engine)
            trackingEngine = nil
        }
    }

    private func initializeTrackingEngine(result: @escaping FlutterResult) {
        cleanupTrackingEngine()

        guard let engine = create_tracking_engine() else {
            result(FlutterError(code: "ENGINE_INIT_FAILED",
                                message: "Failed to create tracking engine",
                                details: nil))
            return
        }

        if initialize_tracking_engine(engine) {
            trackingEngine = engine
            result(true)
        } else {
            destroy_tracking_engine(engine)
            result(FlutterError(code: "ENGINE_INIT_FAILED",
                                message: "Native engine initialization failed",
                                details: nil))
        }
    }

    private func startTracking(result: @escaping FlutterResult) {
        // Frames are streamed from Flutter, so nothing to do here yet.
        result(true)
    }

    private func stopTracking(result: @escaping FlutterResult) {
        // No native timers to stop yet.
        result(true)
    }

    private func processFrame(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let engine = trackingEngine,
              let args = arguments as? [String: Any],
              let frameData = args["data"] as? FlutterStandardTypedData,
              let width = args["width"] as? Int,
              let height = args["height"] as? Int else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid frame data", details: nil))
            return
        }

        guard let cResult = processFrameData(
            engine: engine,
            frameData: frameData,
            width: width,
            height: height
        ) else {
            result(FlutterError(code: "FRAME_PROCESSING_FAILED",
                                message: "Failed to process frame",
                                details: nil))
            return
        }

        eventSink?(buildTrackingResultDictionary(from: cResult))
        result(true)
    }

    private func setCameraParameters(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let engine = trackingEngine else {
            result(FlutterError(code: "ENGINE_NOT_INITIALIZED", message: "Tracking engine not initialized", details: nil))
            return
        }

        guard let args = arguments as? [String: Any],
              let focalLength = args["focalLength"] as? Double,
              let principalX = args["principalX"] as? Double,
              let principalY = args["principalY"] as? Double else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid camera parameters", details: nil))
            return
        }

        set_camera_parameters(engine, focalLength, principalX, principalY)
        result(true)
    }

    private func startCalibration(result: @escaping FlutterResult) {
        result(true)
    }

    private func addCalibrationPoint(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let args = arguments as? [String: Any],
              args["x"] as? Double != nil,
              args["y"] as? Double != nil else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Invalid calibration point", details: nil))
            return
        }
        result(true)
    }

    private func finishCalibration(result: @escaping FlutterResult) {
        result(true)
    }

    private func saveWindowState(result: @escaping FlutterResult) {
        guard let window = NSApplication.shared.mainWindow else {
            result(FlutterError(code: "NO_WINDOW", message: "No main window found", details: nil))
            return
        }

        savedWindowFrame = window.frame
        wasFullscreen = window.styleMask.contains(.fullScreen)
        result(true)
    }

    private func restoreWindowState(result: @escaping FlutterResult) {
        guard let window = NSApplication.shared.mainWindow,
              let savedFrame = savedWindowFrame else {
            result(FlutterError(code: "NO_SAVED_STATE", message: "No saved window state", details: nil))
            return
        }

        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }

        window.setFrame(savedFrame, display: true)
        result(true)
    }

    private func enterFullscreen(result: @escaping FlutterResult) {
        guard let window = NSApplication.shared.mainWindow else {
            result(FlutterError(code: "NO_WINDOW", message: "No main window found", details: nil))
            return
        }

        if !window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
        result(true)
    }

    private func exitFullscreen(result: @escaping FlutterResult) {
        guard let window = NSApplication.shared.mainWindow else {
            result(FlutterError(code: "NO_WINDOW", message: "No main window found", details: nil))
            return
        }

        if window.styleMask.contains(.fullScreen) {
            window.toggleFullScreen(nil)
        }
        result(true)
    }

    private func processFrameData(engine: UnsafeMutableRawPointer,
                                  frameData: FlutterStandardTypedData,
                                  width: Int,
                                  height: Int) -> CTrackingResult? {
        return frameData.data.withUnsafeBytes { buffer -> CTrackingResult? in
            guard let baseAddress = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return nil
            }

            let mutablePointer = UnsafeMutablePointer(mutating: baseAddress)
            return process_frame(engine, mutablePointer, Int32(width), Int32(height))
        }
    }

    private func buildTrackingResultDictionary(from result: CTrackingResult) -> [String: Any] {
        return [
            "faceDistance": result.face_distance,
            "gazeAngleX": result.gaze_angle_x,
            "gazeAngleY": result.gaze_angle_y,
            "eyesFocused": result.eyes_focused,
            "headMoving": result.head_moving,
            "shouldersMoving": result.shoulders_moving
        ]
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
