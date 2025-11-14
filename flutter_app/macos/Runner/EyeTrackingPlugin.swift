import Cocoa
import FlutterMacOS
import AVFoundation

public class EyeTrackingPlugin: NSObject, FlutterPlugin {
    private var trackingEngine: UnsafeMutableRawPointer?
    private var eventSink: FlutterEventSink?
    private var savedWindowFrame: NSRect?
    private var wasFullscreen = false
    private var faceBackendSelection: FaceBackendSelection = .auto
    private var yoloDetector: CoreMLYoloDetector?
    private var yoloDetectorFailed = false

    private enum FaceBackendSelection {
        case auto
        case yolo
        case yunet
        case haar

        init(name: String) {
            switch name.lowercased() {
            case "yolo", "yolov5", "yolov8":
                self = .yolo
            case "yunet":
                self = .yunet
            case "haar", "haarcascade":
                self = .haar
            default:
                self = .auto
            }
        }
    }

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
        case "setFaceDetectionBackend":
            setFaceDetectionBackend(call.arguments, result: result)
        case "setModel":
            setModel(call.arguments, result: result)
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
            // Don't send error, just return nil to avoid crashing the stream
            result(nil)
            return
        }

        let frameBytes = frameData.data

        // Validate frame data size
        let expectedSize = width * height * 3  // RGB format
        guard frameBytes.count == expectedSize else {
            print("[EyeTracking] Invalid frame data size. Expected \(expectedSize), got \(frameBytes.count)")
            result(nil)
            return
        }

        // Detect face rect if needed (but catch any errors)
        let overrideRect: CGRect? = nil  // Temporarily disable CoreML detection to avoid crashes

        guard let cResult = processFrameData(
            engine: engine,
            frameBytes: frameBytes,
            width: width,
            height: height,
            overrideRect: overrideRect
        ) else {
            // Don't send error, just return nil
            result(nil)
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
                                  frameBytes: Data,
                                  width: Int,
                                  height: Int,
                                  overrideRect: CGRect?) -> CTrackingResult? {
        return frameBytes.withUnsafeBytes { buffer -> CTrackingResult? in
            guard let baseAddress = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                return nil
            }

            let mutablePointer = UnsafeMutablePointer(mutating: baseAddress)
            if let rect = overrideRect {
                let normalized = clampNormalized(rect: rect)
                return process_frame_with_override(
                    engine,
                    mutablePointer,
                    Int32(width),
                    Int32(height),
                    true,
                    Float(normalized.origin.x),
                    Float(normalized.origin.y),
                    Float(normalized.size.width),
                    Float(normalized.size.height)
                )
            } else {
                return process_frame_with_override(
                    engine,
                    mutablePointer,
                    Int32(width),
                    Int32(height),
                    false,
                    0,
                    0,
                    0,
                    0
                )
            }
        }
    }

    private func clampNormalized(rect: CGRect) -> CGRect {
        let clampedX = max(0.0, min(1.0, rect.origin.x))
        let clampedY = max(0.0, min(1.0, rect.origin.y))
        let clampedWidth = max(0.0, min(1.0 - clampedX, rect.size.width))
        let clampedHeight = max(0.0, min(1.0 - clampedY, rect.size.height))
        return CGRect(x: clampedX, y: clampedY, width: clampedWidth, height: clampedHeight)
    }

    private func detectFaceRectIfNeeded(frameData: Data, width: Int, height: Int) -> CGRect? {
        guard width > 0, height > 0 else { return nil }
        guard shouldUseCoreMLDetector(), let detector = yoloDetector else {
            return nil
        }
        return detector.detectStrongestFace(in: frameData, width: width, height: height)?.rect
    }

    private func shouldUseCoreMLDetector() -> Bool {
        switch faceBackendSelection {
        case .yolo:
            return ensureYoloDetectorReady()
        case .auto:
            return ensureYoloDetectorReady()
        case .yunet, .haar:
            return false
        }
    }

    private func ensureYoloDetectorReady() -> Bool {
        if yoloDetector != nil {
            return true
        }
        if yoloDetectorFailed {
            return false
        }
        guard let detector = CoreMLYoloDetector() else {
            yoloDetectorFailed = true
            NSLog("[YOLO] Failed to initialize CoreML detector, falling back to native backends")
            return false
        }
        yoloDetector = detector
        return true
    }

    private func buildTrackingResultDictionary(from result: CTrackingResult) -> [String: Any] {
        // Convert face landmarks from C array to Swift array
        var faceLandmarksArray: [[String: Double]] = []
        if result.face_landmarks != nil && result.face_landmarks_count > 0 {
            let landmarksPointer = result.face_landmarks!
            for i in 0..<Int(result.face_landmarks_count) {
                let x = Double(landmarksPointer[i * 2])
                let y = Double(landmarksPointer[i * 2 + 1])
                faceLandmarksArray.append(["x": x, "y": y])
            }
        }

        return [
            "faceDistance": result.face_distance,
            "gazeAngleX": result.gaze_angle_x,
            "gazeAngleY": result.gaze_angle_y,
            "eyesFocused": result.eyes_focused,
            "headMoving": result.head_moving,
            "shouldersMoving": result.shoulders_moving,
            "faceDetected": result.face_detected,
            "faceRect": [
                "detected": result.face_detected,
                "x": result.face_rect_x,
                "y": result.face_rect_y,
                "width": result.face_rect_width,
                "height": result.face_rect_height
            ],
            // Extended tracking data
            "faceLandmarks": faceLandmarksArray,
            "headPose": [
                "x": result.head_pose_pitch,
                "y": result.head_pose_yaw,
                "z": result.head_pose_roll
            ],
            "gazeVector": [
                "x": result.gaze_vector_x,
                "y": result.gaze_vector_y,
                "z": result.gaze_vector_z
            ],
            "confidence": result.confidence
        ]
    }

    private func setFaceDetectionBackend(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let engine = trackingEngine else {
            result(FlutterError(code: "ENGINE_NOT_INITIALIZED", message: "Tracking engine not initialized", details: nil))
            return
        }

        guard let args = arguments as? [String: Any],
              let backendName = args["backend"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing backend parameter", details: nil))
            return
        }

        let selection = FaceBackendSelection(name: backendName)
        faceBackendSelection = selection

        if selection == .yolo || selection == .auto {
            if yoloDetectorFailed {
                yoloDetectorFailed = false
                yoloDetector = nil
            }
            _ = ensureYoloDetectorReady()
        }

        let backendId = EyeTrackingPlugin.backendId(for: backendName)
        set_face_detector_backend(engine, backendId)
        result(true)
    }

    private static func backendId(for backend: String) -> Int32 {
        switch backend.lowercased() {
        case "yolo", "yolov5", "yolov8":
            return 1
        case "yunet":
            return 2
        case "haar", "haarcascade":
            return 3
        default:
            return 0
        }
    }

    private func setModel(_ arguments: Any?, result: @escaping FlutterResult) {
        guard let engine = trackingEngine else {
            result(FlutterError(code: "ENGINE_NOT_INITIALIZED", message: "Tracking engine not initialized", details: nil))
            return
        }

        guard let args = arguments as? [String: Any],
              let modelId = args["modelId"] as? String,
              let modelPath = args["modelPath"] as? String,
              let modelType = args["modelType"] as? String,
              let modelVariant = args["modelVariant"] as? String else {
            result(FlutterError(code: "INVALID_ARGUMENTS", message: "Missing model parameters", details: nil))
            return
        }

        print("Setting model: \(modelId)")
        print("  Path: \(modelPath)")
        print("  Type: \(modelType)")
        print("  Variant: \(modelVariant)")

        // Handle YOLO models specifically
        if modelType.lowercased() == "yolo" {
            // Set YOLO variant in tracking engine
            let variantCString = (modelVariant.prefix(1).lowercased() as NSString).utf8String
            if let variantPtr = variantCString {
                set_yolo_model_variant(engine, variantPtr)
                print("Set YOLO variant to: \(modelVariant)")
            }

            // If YOLO backend not selected, select it
            if faceBackendSelection != .yolo {
                faceBackendSelection = .yolo
                set_face_detector_backend(engine, 1) // 1 = YOLO
            }

            // Ensure YOLO detector is ready
            _ = ensureYoloDetectorReady()
        } else if modelType.lowercased() == "yunet" {
            if faceBackendSelection != .yunet {
                faceBackendSelection = .yunet
                set_face_detector_backend(engine, 2) // 2 = YuNet
            }
        } else if modelType.lowercased() == "haar" {
            if faceBackendSelection != .haar {
                faceBackendSelection = .haar
                set_face_detector_backend(engine, 3) // 3 = Haar
            }
        }

        result(true)
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
