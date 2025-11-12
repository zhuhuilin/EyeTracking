#include "tracking_engine.h"
#include <opencv2/objdetect.hpp>
#include <opencv2/imgproc.hpp>
#include <cmath>
#include <iostream>
#include <filesystem>
#include <cstdlib>
#include <algorithm>
#include <cctype>
#include <optional>

#ifdef __APPLE__
#include <mach-o/dyld.h>
#endif

TrackingEngine::TrackingEngine()
    : focal_length_(2000.0),
      principal_point_(cv::Point2f(0, 0)),
      face_detection_score_threshold_(0.7f),
      calibrated_(false),
      face_detector_load_attempted_(false),
      cascade_load_attempted_(false),
      active_backend_(FaceDetectorBackend::Auto),
      yolo_load_attempted_(false),
      yolo_net_loaded_(false),
      yolo_conf_threshold_(0.45f),
      yolo_nms_threshold_(0.35f),
      yolo_input_size_(640),
      yolo_model_variant_("m") {  // Default to medium variant

    if (const char* backend_env = std::getenv("EYETRACKING_FACE_BACKEND")) {
        active_backend_ = parseFaceDetectorBackend(backend_env);
        std::cout << "[Tracking] Face detector backend set from environment: "
                  << backendName(active_backend_) << std::endl;
    }

    // Allow environment variable to override model variant
    if (const char* variant_env = std::getenv("EYETRACKING_YOLO_VARIANT")) {
        yolo_model_variant_ = variant_env;
    }
}

TrackingEngine::~TrackingEngine() {
}

namespace {
constexpr char kYuNetModelName[] = "face_detection_yunet_2023mar.onnx";
}

bool TrackingEngine::initialize() {
    // Initialize face detector and other models
    // This would typically load Haar cascades or DNN models

    // Print working directory for debugging
    namespace fs = std::filesystem;
    try {
        std::cout << "[Tracking] Current working directory: " << fs::current_path() << std::endl;
    } catch (const std::exception& e) {
        std::cerr << "[Tracking] Could not get current directory: " << e.what() << std::endl;
    }

    std::cout << "[Tracking] Tracking engine initialized" << std::endl;
    std::cout << "[Tracking] Active backend: " << backendName(active_backend_) << std::endl;
    return true;
}

TrackingResult TrackingEngine::processFrame(const cv::Mat& frame, std::optional<cv::Rect> override_face) {
    static int frame_count = 0;
    static bool logged_first_frame = false;

    if (!logged_first_frame) {
        std::cout << "[Tracking] First frame received - Size: " << frame.cols << "x" << frame.rows
                  << ", Channels: " << frame.channels() << ", Type: " << frame.type() << std::endl;
        logged_first_frame = true;
    }

    TrackingResult result = {};
    result.face_detected = false;
    result.face_rect_x = 0.0;
    result.face_rect_y = 0.0;
    result.face_rect_width = 0.0;
    result.face_rect_height = 0.0;

    if (frame.empty()) {
        std::cerr << "[Tracking] Empty frame received!" << std::endl;
        return result;
    }

    // Convert to grayscale for processing
    cv::Mat gray;
    if (frame.channels() == 3) {
        cv::cvtColor(frame, gray, cv::COLOR_BGR2GRAY);
    } else {
        gray = frame.clone();
    }

    // Face detection (run on color frame for DNN, fall back to grayscale cascade)
    cv::Rect face_roi;
    if (override_face && override_face->width > 0 && override_face->height > 0) {
        face_roi = clampRectToFrame(*override_face, frame.size());
    } else {
        face_roi = clampRectToFrame(detectFace(frame), frame.size());
    }

    frame_count++;
    if (frame_count % 30 == 0) {  // Log every 30 frames
        std::cout << "[Tracking] Frame " << frame_count << " - Face detected: "
                  << (face_roi.area() > 0 ? "YES" : "NO") << std::endl;
    }

    if (face_roi.width > 0 && face_roi.height > 0) {
        result.face_detected = true;
        const double frame_width = frame.cols > 0 ? static_cast<double>(frame.cols) : 1.0;
        const double frame_height = frame.rows > 0 ? static_cast<double>(frame.rows) : 1.0;
        result.face_rect_x = face_roi.x / frame_width;
        result.face_rect_y = face_roi.y / frame_height;
        result.face_rect_width = face_roi.width / frame_width;
        result.face_rect_height = face_roi.height / frame_height;

        // Calculate face distance
        result.face_distance = calculateFaceDistance(face_roi);
        
        // Extract face region for eye tracking
        cv::Mat face_region = gray(face_roi);
        
        // Eye detection and gaze estimation
        std::vector<cv::Point2f> eye_points = detectEyes(face_region);
        if (eye_points.size() >= 4) { // At least two eyes with two points each
            cv::Point2f gaze = estimateGaze(eye_points);
            result.gaze_angle_x = gaze.x;
            result.gaze_angle_y = gaze.y;
            result.eyes_focused = std::abs(gaze.x) < 0.1 && std::abs(gaze.y) < 0.1;
        }
        
        // Head pose estimation
        std::vector<cv::Point2f> face_points = detectFaceLandmarks(gray, face_roi);
        if (face_points.size() > 0) {
            cv::Vec3f head_pose = estimateHeadPose(face_points);
            result.head_moving = detectHeadMovement(head_pose, previous_head_pose_);
            previous_head_pose_ = head_pose;
        }
        
        // Shoulder detection
        std::vector<cv::Point2f> shoulder_points = detectShoulders(gray);
        result.shoulders_moving = detectShoulderMovement(shoulder_points, previous_shoulder_points_);
        previous_shoulder_points_ = shoulder_points;
    }
    
    return result;
}

void TrackingEngine::startCalibration() {
    calibration_points_.clear();
    calibrated_ = false;
}

void TrackingEngine::addCalibrationPoint(const cv::Point2f& point) {
    calibration_points_.push_back(point);
}

void TrackingEngine::finishCalibration() {
    if (calibration_points_.size() >= 4) {
        calibrated_ = true;
    }
}

void TrackingEngine::setCameraParameters(double focal_length, const cv::Point2f& principal_point) {
    focal_length_ = focal_length;
    principal_point_ = principal_point;
}

cv::Rect TrackingEngine::detectFace(const cv::Mat& frame) {
    std::vector<FaceDetectorBackend> preference;

    switch (active_backend_) {
        case FaceDetectorBackend::YOLO:
            preference = {FaceDetectorBackend::YOLO, FaceDetectorBackend::YuNet, FaceDetectorBackend::HaarCascade};
            break;
        case FaceDetectorBackend::YuNet:
            preference = {FaceDetectorBackend::YuNet, FaceDetectorBackend::YOLO, FaceDetectorBackend::HaarCascade};
            break;
        case FaceDetectorBackend::HaarCascade:
            preference = {FaceDetectorBackend::HaarCascade, FaceDetectorBackend::YuNet, FaceDetectorBackend::YOLO};
            break;
        case FaceDetectorBackend::Auto:
        default:
            preference = {FaceDetectorBackend::YOLO, FaceDetectorBackend::YuNet, FaceDetectorBackend::HaarCascade};
            break;
    }

    for (FaceDetectorBackend backend : preference) {
        cv::Rect face;
        switch (backend) {
            case FaceDetectorBackend::YOLO:
                face = detectFaceWithYolo(frame);
                break;
            case FaceDetectorBackend::YuNet:
                face = detectFaceWithYuNet(frame);
                break;
            case FaceDetectorBackend::HaarCascade:
                face = detectFaceWithCascade(frame);
                break;
            default:
                continue;
        }
        if (face.area() > 0) {
            return face;
        }
    }

    return cv::Rect();
}

cv::Rect TrackingEngine::detectFaceWithYuNet(const cv::Mat& frame) {
#if EYETRACKING_HAS_YUNET
    if (!ensureFaceDetector() || frame.empty()) {
        return cv::Rect();
    }

    cv::Mat input;
    if (frame.channels() == 1) {
        cv::cvtColor(frame, input, cv::COLOR_GRAY2BGR);
    } else if (frame.channels() == 4) {
        cv::cvtColor(frame, input, cv::COLOR_BGRA2BGR);
    } else {
        input = frame;
    }

    try {
        yunet_face_detector_->setInputSize(input.size());
    } catch (const cv::Exception& e) {
        std::cerr << "Failed to set YuNet input size: " << e.what() << std::endl;
        return cv::Rect();
    }

    cv::Mat detections;
    try {
        yunet_face_detector_->detect(input, detections);
    } catch (const cv::Exception& e) {
        std::cerr << "YuNet face detection failed: " << e.what() << std::endl;
        return cv::Rect();
    }

    if (detections.empty()) {
        return cv::Rect();
    }

    cv::Rect best_rect;
    float best_score = face_detection_score_threshold_;
    for (int i = 0; i < detections.rows; ++i) {
        const float* data = detections.ptr<float>(i);
        if (!data) {
            continue;
        }
        const float score = data[4];
        if (score < best_score) {
            continue;
        }

        cv::Rect candidate(
            static_cast<int>(std::round(data[0])),
            static_cast<int>(std::round(data[1])),
            static_cast<int>(std::round(data[2])),
            static_cast<int>(std::round(data[3]))
        );

        candidate = clampRectToFrame(candidate, input.size());
        if (candidate.area() <= 0) {
            continue;
        }

        best_score = score;
        best_rect = candidate;
    }

    // Expand the rectangle to include full forehead and chin
    if (!best_rect.empty()) {
        best_rect = expandFaceRect(best_rect, input.size());
    }

    return best_rect;
#else
    (void)frame;
    return cv::Rect();
#endif
}

cv::Rect TrackingEngine::detectFaceWithCascade(const cv::Mat& frame) {
    if (!ensureCascadeClassifier() || frame.empty()) {
        return cv::Rect();
    }

    cv::Mat gray;
    if (frame.channels() == 3) {
        cv::cvtColor(frame, gray, cv::COLOR_BGR2GRAY);
    } else if (frame.channels() == 4) {
        cv::cvtColor(frame, gray, cv::COLOR_BGRA2GRAY);
    } else {
        gray = frame;
    }

    std::vector<cv::Rect> faces;
    fallback_face_cascade_.detectMultiScale(
        gray,
        faces,
        1.1,
        4,
        cv::CASCADE_SCALE_IMAGE,
        cv::Size(40, 40)
    );

    if (faces.empty()) {
        return cv::Rect();
    }

    cv::Rect largest = *std::max_element(
        faces.begin(),
        faces.end(),
        [](const cv::Rect& a, const cv::Rect& b) {
            return a.area() < b.area();
        }
    );

    // Expand the rectangle to include full forehead and chin
    return expandFaceRect(largest, frame.size());
}

bool TrackingEngine::ensureFaceDetector() {
#if EYETRACKING_HAS_YUNET
    if (!yunet_face_detector_.empty()) {
        return true;
    }

    if (face_detector_load_attempted_) {
        return false;
    }
    face_detector_load_attempted_ = true;

    const std::string model_path = resolveFaceModelPath();
    if (model_path.empty()) {
        std::cerr << "[Tracking] YuNet face detection model not found. "
                  << "Set EYETRACKING_FACE_MODEL environment variable to the ONNX file path, "
                  << "or place face_detection_yunet_2023mar.onnx in core/models/ directory."
                  << std::endl;
        return false;
    }

    std::cout << "[Tracking] Loading YuNet face detector from: " << model_path << std::endl;

    try {
        yunet_face_detector_ = cv::FaceDetectorYN::create(
            model_path,
            "",
            cv::Size(320, 320),
            face_detection_score_threshold_,
            0.3f,
            5000
        );
        if (!yunet_face_detector_.empty()) {
            std::cout << "[Tracking] YuNet face detector loaded successfully" << std::endl;
        }
    } catch (const cv::Exception& e) {
        std::cerr << "[Tracking] Failed to initialize YuNet face detector: "
                  << e.what() << std::endl;
        std::cerr << "[Tracking] Will fall back to alternative face detection methods" << std::endl;
    }

    return !yunet_face_detector_.empty();
#else
    return false;
#endif
}

bool TrackingEngine::ensureCascadeClassifier() {
    if (!fallback_face_cascade_.empty()) {
        return true;
    }

    if (cascade_load_attempted_) {
        return false;
    }
    cascade_load_attempted_ = true;

    namespace fs = std::filesystem;
    std::vector<std::string> cascade_candidates;

#ifdef EYETRACKING_DEFAULT_HAAR_CASCADE_PATH
    // Try the bundled model first
    cascade_candidates.push_back(EYETRACKING_DEFAULT_HAAR_CASCADE_PATH);
#endif

#ifdef __APPLE__
    // On macOS, try to find the app bundle Resources directory
    char exe_path[1024];
    uint32_t size = sizeof(exe_path);
    if (_NSGetExecutablePath(exe_path, &size) == 0) {
        fs::path exe_dir = fs::path(exe_path).parent_path();
        // In macOS app bundle: MyApp.app/Contents/MacOS/MyApp
        // Resources are at: MyApp.app/Contents/Resources/
        fs::path resources_dir = exe_dir.parent_path() / "Resources";
        cascade_candidates.push_back((resources_dir / "haarcascade_frontalface_default.xml").string());

        // Also try Flutter's source directory
        fs::path project_root = exe_dir.parent_path().parent_path().parent_path().parent_path().parent_path();
        fs::path flutter_resources = project_root / "macos" / "Runner" / "Resources";
        cascade_candidates.push_back((flutter_resources / "haarcascade_frontalface_default.xml").string());
    }
#endif

    // Add absolute path fallbacks
    cascade_candidates.push_back("/Users/huilinzhu/Projects/EyeTracking/flutter_app/macos/Runner/Resources/haarcascade_frontalface_default.xml");
    cascade_candidates.push_back("/Users/huilinzhu/Projects/EyeTracking/core/models/haarcascade_frontalface_default.xml");

    // Then try standard installation locations
    cascade_candidates.insert(cascade_candidates.end(), {
        "/opt/homebrew/share/opencv4/haarcascades/haarcascade_frontalface_default.xml",
        "/opt/homebrew/Cellar/opencv/4.12.0_14/share/opencv4/haarcascades/haarcascade_frontalface_default.xml",
        "/usr/local/share/opencv4/haarcascades/haarcascade_frontalface_default.xml",
        "/usr/share/opencv4/haarcascades/haarcascade_frontalface_default.xml",
        "/usr/share/opencv/haarcascades/haarcascade_frontalface_default.xml",
        // Also try relative to the executable
        "../Resources/haarcascade_frontalface_default.xml",
        "../../Resources/haarcascade_frontalface_default.xml",
        "core/models/haarcascade_frontalface_default.xml",
        "../core/models/haarcascade_frontalface_default.xml",
        "../../core/models/haarcascade_frontalface_default.xml"
    });

    for (const auto& candidate : cascade_candidates) {
        fs::path cascade_path(candidate);
        if (!candidate.empty() && fs::exists(cascade_path)) {
            if (fallback_face_cascade_.load(candidate)) {
                std::cout << "[Tracking] Loaded Haar Cascade from: " << candidate << std::endl;
                return true;
            }
        }
    }

    std::cerr << "Warning: Failed to load Haar cascade fallback for face detection."
              << std::endl;
    return !fallback_face_cascade_.empty();
}

bool TrackingEngine::ensureYoloFaceNet() {
    if (yolo_net_loaded_) {
        return true;
    }

    if (yolo_load_attempted_) {
        return false;
    }
    yolo_load_attempted_ = true;

#ifdef EYETRACKING_DEFAULT_YOLO_FACE_MODEL_PATH
    const std::string default_path = EYETRACKING_DEFAULT_YOLO_FACE_MODEL_PATH;
#else
    const std::string default_path;
#endif

    std::string model_path = resolveYoloModelPath();
    if (model_path.empty() && !default_path.empty()) {
        model_path = default_path;
    }

    if (model_path.empty()) {
        std::cout << "[Tracking] YOLO face model not found (optional). "
                  << "Set EYETRACKING_YOLO_FACE_MODEL environment variable or place "
                  << "yolov5n-face.onnx in core/models/ to enable YOLO detection. "
                  << "See core/models/YOLO_MODEL_README.txt for details." << std::endl;
        return false;
    }

    std::cout << "[Tracking] Loading YOLO face detector from: " << model_path << std::endl;

    try {
        yolo_face_net_ = cv::dnn::readNet(model_path);
        yolo_face_net_.setPreferableBackend(cv::dnn::DNN_BACKEND_OPENCV);
        yolo_face_net_.setPreferableTarget(cv::dnn::DNN_TARGET_CPU);
        yolo_net_loaded_ = true;
        std::cout << "[Tracking] YOLO face detector loaded successfully" << std::endl;
    } catch (const cv::Exception& e) {
        std::cerr << "[Tracking] Failed to load YOLO face model from " << model_path
                  << ": " << e.what() << std::endl;
        std::cerr << "[Tracking] Will fall back to YuNet or Haar Cascade detection." << std::endl;
    }

    return yolo_net_loaded_;
}

std::string TrackingEngine::resolveFaceModelPath() const {
#if EYETRACKING_HAS_YUNET
    namespace fs = std::filesystem;
    auto tryResolve = [](const fs::path& candidate) -> std::string {
        if (candidate.empty()) {
            return {};
        }
        try {
            if (fs::exists(candidate)) {
                return fs::weakly_canonical(candidate).string();
            }
        } catch (const fs::filesystem_error&) {
            // Ignore and continue to next candidate.
        }
        return {};
    };

    if (const char* env_path = std::getenv("EYETRACKING_FACE_MODEL")) {
        std::cout << "[Tracking] Trying env path: " << env_path << std::endl;
        const std::string resolved = tryResolve(fs::path(env_path));
        if (!resolved.empty()) {
            std::cout << "[Tracking] Found model at env path" << std::endl;
            return resolved;
        }
    }

#ifdef EYETRACKING_DEFAULT_FACE_MODEL_PATH
    {
        std::cout << "[Tracking] Trying compile-time path: " << EYETRACKING_DEFAULT_FACE_MODEL_PATH << std::endl;
        const std::string resolved =
            tryResolve(fs::path(EYETRACKING_DEFAULT_FACE_MODEL_PATH));
        if (!resolved.empty()) {
            std::cout << "[Tracking] Found model at compile-time path" << std::endl;
            return resolved;
        }
    }
#endif

    // Try to get the executable path to find the Resources directory
    std::vector<std::string> candidates;

#ifdef __APPLE__
    // On macOS, try to find the app bundle Resources directory
    char exe_path[1024];
    uint32_t size = sizeof(exe_path);
    if (_NSGetExecutablePath(exe_path, &size) == 0) {
        fs::path exe_dir = fs::path(exe_path).parent_path();
        std::cout << "[Tracking] Executable path: " << exe_path << std::endl;
        std::cout << "[Tracking] Executable dir: " << exe_dir << std::endl;

        // In macOS app bundle: MyApp.app/Contents/MacOS/MyApp
        // Resources are at: MyApp.app/Contents/Resources/
        fs::path resources_dir = exe_dir.parent_path() / "Resources";
        candidates.push_back((resources_dir / kYuNetModelName).string());

        // Also try Flutter's ephemeral directory structure
        // Flutter run uses: flutter_app/build/macos/Build/Products/Debug/eyeball_tracking.app/Contents/MacOS/eyeball_tracking
        // Source is at: flutter_app/macos/Runner/Resources/
        fs::path project_root = exe_dir.parent_path().parent_path().parent_path().parent_path().parent_path();
        fs::path flutter_resources = project_root / "macos" / "Runner" / "Resources";
        candidates.push_back((flutter_resources / kYuNetModelName).string());
    }
#endif

    // Add absolute path to source directory as ultimate fallback
    candidates.push_back("/Users/huilinzhu/Projects/EyeTracking/flutter_app/macos/Runner/Resources/" + std::string(kYuNetModelName));
    candidates.push_back("/Users/huilinzhu/Projects/EyeTracking/core/models/" + std::string(kYuNetModelName));

    candidates.insert(candidates.end(), {
        std::string("../Resources/") + kYuNetModelName,
        std::string("../../Resources/") + kYuNetModelName,
        std::string("Resources/") + kYuNetModelName,
        std::string("./") + kYuNetModelName,
        std::string(kYuNetModelName),
        std::string("core/models/") + kYuNetModelName,
        std::string("../core/models/") + kYuNetModelName,
        std::string("../../core/models/") + kYuNetModelName,
        std::string("/usr/local/share/eyeball_tracking/models/") + kYuNetModelName,
        std::string("/usr/share/eyeball_tracking/models/") + kYuNetModelName
    });

    std::cout << "[Tracking] Trying " << candidates.size() << " candidate paths for YuNet model..." << std::endl;
    for (const auto& candidate : candidates) {
        const std::string resolved = tryResolve(fs::path(candidate));
        if (!resolved.empty()) {
            std::cout << "[Tracking] Found YuNet model at: " << resolved << std::endl;
            return resolved;
        }
    }
    std::cout << "[Tracking] No YuNet model found in any candidate path" << std::endl;
#endif

    return {};
}

cv::Rect TrackingEngine::clampRectToFrame(const cv::Rect& rect, const cv::Size& size) {
    if (rect.width <= 0 || rect.height <= 0 || size.width <= 0 || size.height <= 0) {
        return cv::Rect();
    }
    const cv::Rect bounds(0, 0, size.width, size.height);
    cv::Rect clamped = rect & bounds;
    if (clamped.width <= 0 || clamped.height <= 0) {
        return cv::Rect();
    }
    return clamped;
}

cv::Rect TrackingEngine::expandFaceRect(const cv::Rect& face_rect, const cv::Size& frame_size) {
    // Expand the face rectangle to include full forehead and chin
    // Face detection models typically focus on eyes, nose, and mouth
    // We need to expand upward (forehead) and downward (chin) more than sides

    if (face_rect.empty() || frame_size.width <= 0 || frame_size.height <= 0) {
        return face_rect;
    }

    // Expansion factors
    const float width_expansion = 0.10f;   // Expand width by 10% on each side
    const float top_expansion = 0.30f;     // Expand top by 30% (forehead)
    const float bottom_expansion = 0.20f;  // Expand bottom by 20% (chin)

    // Calculate expanded dimensions
    int expand_width = static_cast<int>(face_rect.width * width_expansion);
    int expand_top = static_cast<int>(face_rect.height * top_expansion);
    int expand_bottom = static_cast<int>(face_rect.height * bottom_expansion);

    // Create expanded rectangle
    cv::Rect expanded(
        face_rect.x - expand_width,
        face_rect.y - expand_top,
        face_rect.width + (2 * expand_width),
        face_rect.height + expand_top + expand_bottom
    );

    // Clamp to frame bounds
    return clampRectToFrame(expanded, frame_size);
}

double TrackingEngine::calculateFaceDistance(const cv::Rect& face_roi) {
    // Calculate distance based on face size and camera focal length
    // Assumes average face width of 14cm
    const double known_face_width = 14.0; // cm
    double pixel_width = face_roi.width;
    
    if (pixel_width > 0 && focal_length_ > 0) {
        return (known_face_width * focal_length_) / pixel_width;
    }
    
    return 0.0;
}

std::vector<cv::Point2f> TrackingEngine::detectEyes(const cv::Mat& face_roi) {
    std::vector<cv::Point2f> eye_points;

    // Simple eye detection using Haar cascade
    static cv::CascadeClassifier eye_cascade;
    static bool cascade_load_attempted = false;

    if (eye_cascade.empty() && !cascade_load_attempted) {
        cascade_load_attempted = true;
        std::vector<std::string> eye_cascade_paths;

#ifdef __APPLE__
        // On macOS, try to find the app bundle Resources directory
        char exe_path[1024];
        uint32_t size = sizeof(exe_path);
        if (_NSGetExecutablePath(exe_path, &size) == 0) {
            std::filesystem::path exe_dir = std::filesystem::path(exe_path).parent_path();
            std::filesystem::path resources_dir = exe_dir.parent_path() / "Resources";
            eye_cascade_paths.push_back((resources_dir / "haarcascade_eye.xml").string());

            // Also try Flutter's source directory
            std::filesystem::path project_root = exe_dir.parent_path().parent_path().parent_path().parent_path().parent_path();
            std::filesystem::path flutter_resources = project_root / "macos" / "Runner" / "Resources";
            eye_cascade_paths.push_back((flutter_resources / "haarcascade_eye.xml").string());
        }
#endif

        // Add absolute path fallbacks
        eye_cascade_paths.push_back("/Users/huilinzhu/Projects/EyeTracking/flutter_app/macos/Runner/Resources/haarcascade_eye.xml");
        eye_cascade_paths.push_back("/Users/huilinzhu/Projects/EyeTracking/core/models/haarcascade_eye.xml");

        eye_cascade_paths.insert(eye_cascade_paths.end(), {
            "core/models/haarcascade_eye.xml",
            "../core/models/haarcascade_eye.xml",
            "../../core/models/haarcascade_eye.xml",
            "../Resources/haarcascade_eye.xml",
            "../../Resources/haarcascade_eye.xml",
            "/opt/homebrew/share/opencv4/haarcascades/haarcascade_eye.xml",
            "/opt/homebrew/Cellar/opencv/4.12.0_14/share/opencv4/haarcascades/haarcascade_eye.xml",
            "/usr/local/share/opencv4/haarcascades/haarcascade_eye.xml",
            "/usr/share/opencv4/haarcascades/haarcascade_eye.xml"
        });

        for (const auto& path : eye_cascade_paths) {
            if (eye_cascade.load(path)) {
                break;
            }
        }
    }

    if (!eye_cascade.empty()) {
        std::vector<cv::Rect> eyes;
        eye_cascade.detectMultiScale(face_roi, eyes, 1.1, 2, 0, cv::Size(30, 30));

        // Convert eye positions to points
        for (const auto& eye : eyes) {
            cv::Point2f center(eye.x + eye.width/2.0f, eye.y + eye.height/2.0f);
            eye_points.push_back(center);
        }
    }

    return eye_points;
}

cv::Point2f TrackingEngine::estimateGaze(const std::vector<cv::Point2f>& eye_points) {
    // Improved gaze estimation using pupil center and eye corners
    if (eye_points.size() < 4) { // Need at least left and right eye points
        return cv::Point2f(0, 0);
    }

    // Assume eye_points are ordered as: [left_eye_center, right_eye_center, left_eye_corner1, left_eye_corner2, right_eye_corner1, right_eye_corner2]
    cv::Point2f left_eye_center = eye_points[0];
    cv::Point2f right_eye_center = eye_points[1];

    // Calculate horizontal gaze based on eye center positions
    float eye_distance = cv::norm(left_eye_center - right_eye_center);
    float gaze_x = (left_eye_center.x - right_eye_center.x) / eye_distance;

    // Calculate vertical gaze based on eye aspect ratio (if eye corners are available)
    float gaze_y = 0.0f;
    if (eye_points.size() >= 6) {
        // Calculate eye aspect ratios
        float left_eye_width = cv::norm(eye_points[2] - eye_points[3]);
        float left_eye_height = cv::norm(cv::Point2f(eye_points[2].x, eye_points[3].y) - cv::Point2f(eye_points[3].x, eye_points[2].y));
        float right_eye_width = cv::norm(eye_points[4] - eye_points[5]);
        float right_eye_height = cv::norm(cv::Point2f(eye_points[4].x, eye_points[5].y) - cv::Point2f(eye_points[5].x, eye_points[4].y));

        float left_aspect = left_eye_height / left_eye_width;
        float right_aspect = right_eye_height / right_eye_width;
        float avg_aspect = (left_aspect + right_aspect) / 2.0f;

        // Higher aspect ratio indicates more open eyes (looking up), lower indicates closed/squinting (looking down)
        gaze_y = (avg_aspect - 0.3f) / 0.2f; // Normalize around typical aspect ratio
        gaze_y = std::max(-1.0f, std::min(1.0f, gaze_y));
    }

    return cv::Point2f(gaze_x, gaze_y);
}

std::vector<cv::Point2f> TrackingEngine::detectFaceLandmarks(const cv::Mat& frame, const cv::Rect& face_roi) {
    std::vector<cv::Point2f> landmarks;

    // Enhanced face landmark detection using facial feature analysis
    // This provides more accurate landmarks for head pose estimation

    // Extract face region
    cv::Mat face_region = frame(face_roi);

    // Detect eyes more precisely for landmark estimation
    static cv::CascadeClassifier eye_cascade;
    static bool cascade_load_attempted = false;
    std::vector<cv::Rect> eyes;

    if (eye_cascade.empty() && !cascade_load_attempted) {
        cascade_load_attempted = true;
        std::vector<std::string> eye_cascade_paths;

#ifdef __APPLE__
        // On macOS, try to find the app bundle Resources directory
        char exe_path[1024];
        uint32_t size = sizeof(exe_path);
        if (_NSGetExecutablePath(exe_path, &size) == 0) {
            std::filesystem::path exe_dir = std::filesystem::path(exe_path).parent_path();
            std::filesystem::path resources_dir = exe_dir.parent_path() / "Resources";
            eye_cascade_paths.push_back((resources_dir / "haarcascade_eye.xml").string());

            // Also try Flutter's source directory
            std::filesystem::path project_root = exe_dir.parent_path().parent_path().parent_path().parent_path().parent_path();
            std::filesystem::path flutter_resources = project_root / "macos" / "Runner" / "Resources";
            eye_cascade_paths.push_back((flutter_resources / "haarcascade_eye.xml").string());
        }
#endif

        // Add absolute path fallbacks
        eye_cascade_paths.push_back("/Users/huilinzhu/Projects/EyeTracking/flutter_app/macos/Runner/Resources/haarcascade_eye.xml");
        eye_cascade_paths.push_back("/Users/huilinzhu/Projects/EyeTracking/core/models/haarcascade_eye.xml");

        eye_cascade_paths.insert(eye_cascade_paths.end(), {
            "core/models/haarcascade_eye.xml",
            "../core/models/haarcascade_eye.xml",
            "../../core/models/haarcascade_eye.xml",
            "../Resources/haarcascade_eye.xml",
            "../../Resources/haarcascade_eye.xml",
            "/opt/homebrew/share/opencv4/haarcascades/haarcascade_eye.xml",
            "/opt/homebrew/Cellar/opencv/4.12.0_14/share/opencv4/haarcascades/haarcascade_eye.xml",
            "/usr/local/share/opencv4/haarcascades/haarcascade_eye.xml",
            "/usr/share/opencv4/haarcascades/haarcascade_eye.xml"
        });

        for (const auto& path : eye_cascade_paths) {
            if (eye_cascade.load(path)) {
                break;
            }
        }
    }

    if (!eye_cascade.empty()) {
        eye_cascade.detectMultiScale(face_region, eyes, 1.1, 2, 0, cv::Size(20, 20));
    }

    // Basic facial landmarks based on detected features
    float face_x = face_roi.x;
    float face_y = face_roi.y;
    float face_w = face_roi.width;
    float face_h = face_roi.height;

    // Corner points
    landmarks.push_back(cv::Point2f(face_x, face_y)); // Top-left
    landmarks.push_back(cv::Point2f(face_x + face_w, face_y)); // Top-right
    landmarks.push_back(cv::Point2f(face_x, face_y + face_h)); // Bottom-left
    landmarks.push_back(cv::Point2f(face_x + face_w, face_y + face_h)); // Bottom-right

    // Eye positions (if detected)
    if (eyes.size() >= 2) {
        // Sort eyes by x position (left to right)
        std::sort(eyes.begin(), eyes.end(), [](const cv::Rect& a, const cv::Rect& b) {
            return a.x < b.x;
        });

        cv::Point2f left_eye_center(face_x + eyes[0].x + eyes[0].width/2.0f, face_y + eyes[0].y + eyes[0].height/2.0f);
        cv::Point2f right_eye_center(face_x + eyes[1].x + eyes[1].width/2.0f, face_y + eyes[1].y + eyes[1].height/2.0f);

        landmarks.push_back(left_eye_center);
        landmarks.push_back(right_eye_center);

        // Eye corners (estimated)
        landmarks.push_back(cv::Point2f(left_eye_center.x - eyes[0].width/3.0f, left_eye_center.y)); // Left eye left corner
        landmarks.push_back(cv::Point2f(left_eye_center.x + eyes[0].width/3.0f, left_eye_center.y)); // Left eye right corner
        landmarks.push_back(cv::Point2f(right_eye_center.x - eyes[1].width/3.0f, right_eye_center.y)); // Right eye left corner
        landmarks.push_back(cv::Point2f(right_eye_center.x + eyes[1].width/3.0f, right_eye_center.y)); // Right eye right corner
    } else {
        // Fallback eye positions based on face proportions
        float eye_y = face_y + face_h * 0.3f;
        float eye_spacing = face_w * 0.25f;
        landmarks.push_back(cv::Point2f(face_x + face_w/2.0f - eye_spacing, eye_y)); // Left eye
        landmarks.push_back(cv::Point2f(face_x + face_w/2.0f + eye_spacing, eye_y)); // Right eye
    }

    // Nose tip (estimated)
    landmarks.push_back(cv::Point2f(face_x + face_w/2.0f, face_y + face_h * 0.5f));

    // Mouth corners (estimated)
    float mouth_y = face_y + face_h * 0.75f;
    float mouth_width = face_w * 0.4f;
    landmarks.push_back(cv::Point2f(face_x + face_w/2.0f - mouth_width/2.0f, mouth_y)); // Left mouth corner
    landmarks.push_back(cv::Point2f(face_x + face_w/2.0f + mouth_width/2.0f, mouth_y)); // Right mouth corner

    return landmarks;
}

cv::Vec3f TrackingEngine::estimateHeadPose(const std::vector<cv::Point2f>& face_points) {
    // Improved head pose estimation using facial landmarks
    // This uses geometric analysis of facial features for pose estimation

    cv::Vec3f pose(0, 0, 0); // pitch, yaw, roll

    if (face_points.size() < 10) {
        return pose; // Need sufficient landmarks
    }

    // Extract key facial points
    // Assuming landmarks are ordered as: corners, eyes, eye_corners, nose, mouth_corners
    cv::Point2f left_eye = face_points[4];   // Left eye center
    cv::Point2f right_eye = face_points[5];  // Right eye center
    cv::Point2f nose = face_points[10];      // Nose tip
    cv::Point2f left_mouth = face_points[11]; // Left mouth corner
    cv::Point2f right_mouth = face_points[12]; // Right mouth corner

    // Calculate eye line vector
    cv::Point2f eye_center = (left_eye + right_eye) * 0.5f;
    cv::Point2f eye_vector = right_eye - left_eye;
    float eye_distance = cv::norm(eye_vector);

    // Normalize eye vector
    if (eye_distance > 0) {
        eye_vector /= eye_distance;
    }

    // Calculate yaw (horizontal rotation) based on eye line tilt
    pose[1] = -eye_vector.y; // Negative because positive yaw is clockwise

    // Calculate pitch (vertical rotation) based on nose position relative to eyes
    float nose_to_eye_distance = nose.y - eye_center.y;
    float expected_nose_distance = eye_distance * 0.8f; // Expected distance based on face proportions
    pose[0] = (nose_to_eye_distance - expected_nose_distance) / expected_nose_distance;

    // Calculate roll (rotation around forward axis) based on mouth symmetry
    float mouth_center_x = (left_mouth.x + right_mouth.x) * 0.5f;
    float face_center_x = (face_points[0].x + face_points[1].x) * 0.5f; // Face center from corners
    float mouth_offset = mouth_center_x - face_center_x;
    pose[2] = mouth_offset / eye_distance; // Normalize by eye distance

    // Clamp values to reasonable ranges
    pose[0] = std::max(-1.0f, std::min(1.0f, pose[0])); // Pitch: -1 to 1
    pose[1] = std::max(-1.0f, std::min(1.0f, pose[1])); // Yaw: -1 to 1
    pose[2] = std::max(-0.5f, std::min(0.5f, pose[2])); // Roll: -0.5 to 0.5 (less range)

    return pose;
}

bool TrackingEngine::detectHeadMovement(const cv::Vec3f& current_pose, const cv::Vec3f& previous_pose) {
    // Detect if head has moved significantly
    float movement_threshold = 0.1f;
    
    float pitch_diff = std::abs(current_pose[0] - previous_pose[0]);
    float yaw_diff = std::abs(current_pose[1] - previous_pose[1]);
    float roll_diff = std::abs(current_pose[2] - previous_pose[2]);
    
    return (pitch_diff > movement_threshold || 
            yaw_diff > movement_threshold || 
            roll_diff > movement_threshold);
}

std::vector<cv::Point2f> TrackingEngine::detectShoulders(const cv::Mat& frame) {
    std::vector<cv::Point2f> shoulder_points;

    // Enhanced shoulder detection using edge detection and contour analysis
    // This provides a basic approximation of shoulder positions

    int frame_height = frame.rows;
    int frame_width = frame.cols;

    // Focus on lower portion of frame where shoulders are likely to be
    cv::Rect roi(0, frame_height * 0.6f, frame_width, frame_height * 0.4f);
    cv::Mat shoulder_region = frame(roi);

    // Apply Gaussian blur to reduce noise
    cv::Mat blurred;
    cv::GaussianBlur(shoulder_region, blurred, cv::Size(5, 5), 0);

    // Edge detection using Canny
    cv::Mat edges;
    cv::Canny(blurred, edges, 50, 150);

    // Find contours in the edge image
    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(edges, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);

    // Filter contours that could be shoulders (based on size and position)
    std::vector<cv::Rect> shoulder_candidates;
    for (const auto& contour : contours) {
        cv::Rect bounding_rect = cv::boundingRect(contour);
        double area = cv::contourArea(contour);

        // Filter based on reasonable shoulder size and aspect ratio
        if (area > 500 && area < 10000) { // Size constraints
            double aspect_ratio = static_cast<double>(bounding_rect.width) / bounding_rect.height;
            if (aspect_ratio > 0.5 && aspect_ratio < 3.0) { // Aspect ratio constraints
                shoulder_candidates.push_back(bounding_rect);
            }
        }
    }

    // Sort candidates by x position (left to right)
    std::sort(shoulder_candidates.begin(), shoulder_candidates.end(),
              [](const cv::Rect& a, const cv::Rect& b) { return a.x < b.x; });

    // Select the two most likely shoulder candidates
    if (shoulder_candidates.size() >= 2) {
        // Take the leftmost and rightmost candidates as shoulders
        cv::Rect left_shoulder = shoulder_candidates.front();
        cv::Rect right_shoulder = shoulder_candidates.back();

        // Convert to absolute coordinates
        shoulder_points.push_back(cv::Point2f(
            left_shoulder.x + left_shoulder.width/2.0f,
            roi.y + left_shoulder.y + left_shoulder.height/2.0f
        ));
        shoulder_points.push_back(cv::Point2f(
            right_shoulder.x + right_shoulder.width/2.0f,
            roi.y + right_shoulder.y + right_shoulder.height/2.0f
        ));
    } else {
        // Fallback to default positions if shoulder detection fails
        shoulder_points.push_back(cv::Point2f(frame_width * 0.25f, frame_height * 0.8f));
        shoulder_points.push_back(cv::Point2f(frame_width * 0.75f, frame_height * 0.8f));
    }

    return shoulder_points;
}

bool TrackingEngine::detectShoulderMovement(const std::vector<cv::Point2f>& current_points, 
                                           const std::vector<cv::Point2f>& previous_points) {
    if (current_points.size() != 2 || previous_points.size() != 2) {
        return false;
    }
    
    float movement_threshold = 10.0f; // pixels
    
    float left_movement = cv::norm(current_points[0] - previous_points[0]);
    float right_movement = cv::norm(current_points[1] - previous_points[1]);
    
    return (left_movement > movement_threshold || right_movement > movement_threshold);
}

// C interface implementation
extern "C" {
    void* create_tracking_engine() {
        return new TrackingEngine();
    }
    
    void destroy_tracking_engine(void* engine) {
        delete static_cast<TrackingEngine*>(engine);
    }
    
    bool initialize_tracking_engine(void* engine) {
        return static_cast<TrackingEngine*>(engine)->initialize();
    }
    
    CTrackingResult process_frame(void* engine, unsigned char* frame_data, int width, int height) {
        TrackingEngine* tracking_engine = static_cast<TrackingEngine*>(engine);
        
        // Convert raw data to OpenCV Mat
        cv::Mat frame(height, width, CV_8UC3, frame_data);
        
        TrackingResult result = tracking_engine->processFrame(frame);
        
        // Convert to C struct
        CTrackingResult c_result = {};
        c_result.face_distance = result.face_distance;
        c_result.gaze_angle_x = result.gaze_angle_x;
        c_result.gaze_angle_y = result.gaze_angle_y;
        c_result.eyes_focused = result.eyes_focused;
        c_result.head_moving = result.head_moving;
        c_result.shoulders_moving = result.shoulders_moving;
        c_result.face_detected = result.face_detected;
        c_result.face_rect_x = result.face_rect_x;
        c_result.face_rect_y = result.face_rect_y;
        c_result.face_rect_width = result.face_rect_width;
        c_result.face_rect_height = result.face_rect_height;
        
        return c_result;
    }

    CTrackingResult process_frame_with_override(void* engine,
                                                unsigned char* frame_data,
                                                int width,
                                                int height,
                                                bool has_override,
                                                float norm_x,
                                                float norm_y,
                                                float norm_width,
                                                float norm_height) {
        TrackingEngine* tracking_engine = static_cast<TrackingEngine*>(engine);
        if (tracking_engine == nullptr) {
            return {};
        }

        cv::Mat frame(height, width, CV_8UC3, frame_data);
        std::optional<cv::Rect> override_rect;

        if (has_override && width > 0 && height > 0) {
            auto clamp_unit = [](float value) -> float {
                if (std::isfinite(value)) {
                    if (value < 0.0f) {
                        return 0.0f;
                    }
                    if (value > 1.0f) {
                        return 1.0f;
                    }
                    return value;
                }
                return 0.0f;
            };

            const float clamped_x = clamp_unit(norm_x);
            const float clamped_y = clamp_unit(norm_y);
            const float clamped_w = clamp_unit(norm_width);
            const float clamped_h = clamp_unit(norm_height);

            const int px = static_cast<int>(std::round(clamped_x * static_cast<float>(width)));
            const int py = static_cast<int>(std::round(clamped_y * static_cast<float>(height)));
            const int pw = static_cast<int>(std::round(clamped_w * static_cast<float>(width)));
            const int ph = static_cast<int>(std::round(clamped_h * static_cast<float>(height)));

            if (pw > 0 && ph > 0) {
                override_rect = cv::Rect(px, py, pw, ph);
            }
        }

        TrackingResult result = tracking_engine->processFrame(frame, override_rect);

        CTrackingResult c_result = {};
        c_result.face_distance = result.face_distance;
        c_result.gaze_angle_x = result.gaze_angle_x;
        c_result.gaze_angle_y = result.gaze_angle_y;
        c_result.eyes_focused = result.eyes_focused;
        c_result.head_moving = result.head_moving;
        c_result.shoulders_moving = result.shoulders_moving;
        c_result.face_detected = result.face_detected;
        c_result.face_rect_x = result.face_rect_x;
        c_result.face_rect_y = result.face_rect_y;
        c_result.face_rect_width = result.face_rect_width;
        c_result.face_rect_height = result.face_rect_height;

        return c_result;
    }
    
    void set_camera_parameters(void* engine, double focal_length, double principal_x, double principal_y) {
        TrackingEngine* tracking_engine = static_cast<TrackingEngine*>(engine);
        tracking_engine->setCameraParameters(focal_length, cv::Point2f(principal_x, principal_y));
    }

    void set_face_detector_backend(void* engine, int backend) {
        TrackingEngine* tracking_engine = static_cast<TrackingEngine*>(engine);
        if (tracking_engine == nullptr) {
            return;
        }

        TrackingEngine::FaceDetectorBackend mapped = TrackingEngine::FaceDetectorBackend::Auto;
        switch (backend) {
            case 1:
                mapped = TrackingEngine::FaceDetectorBackend::YOLO;
                break;
            case 2:
                mapped = TrackingEngine::FaceDetectorBackend::YuNet;
                break;
            case 3:
                mapped = TrackingEngine::FaceDetectorBackend::HaarCascade;
                break;
            case 0:
            default:
                mapped = TrackingEngine::FaceDetectorBackend::Auto;
                break;
        }
        tracking_engine->setFaceDetectorBackend(mapped);
    }

    void set_yolo_model_variant(void* engine, const char* variant) {
        TrackingEngine* tracking_engine = static_cast<TrackingEngine*>(engine);
        if (tracking_engine == nullptr || variant == nullptr) {
            return;
        }
        tracking_engine->setYoloModelVariant(std::string(variant));
    }
}

cv::Rect TrackingEngine::detectFaceWithYolo(const cv::Mat& frame) {
    if (!ensureYoloFaceNet() || frame.empty()) {
        return cv::Rect();
    }

    cv::Mat blob = cv::dnn::blobFromImage(
        frame,
        1.0f / 255.0f,
        cv::Size(yolo_input_size_, yolo_input_size_),
        cv::Scalar(),
        true,
        false
    );

    yolo_face_net_.setInput(blob);
    cv::Mat output = yolo_face_net_.forward();

    if (output.dims != 3) {
        return cv::Rect();
    }

    const int rows = output.size[1];
    const int dimensions = output.size[2];

    if (dimensions < 6 || rows <= 0) {
        return cv::Rect();
    }

    const float* data = reinterpret_cast<const float*>(output.data);
    std::vector<cv::Rect> boxes;
    std::vector<float> confidences;

    for (int i = 0; i < rows; ++i) {
        const float* row = data + i * dimensions;
        float objectness = row[4];
        float class_score = dimensions > 5 ? row[5] : 1.0f;
        float confidence = objectness * class_score;

        if (confidence < yolo_conf_threshold_) {
            continue;
        }

        float center_x = row[0];
        float center_y = row[1];
        float width = row[2];
        float height = row[3];

        float x = (center_x - width / 2.0f) / static_cast<float>(yolo_input_size_) * frame.cols;
        float y = (center_y - height / 2.0f) / static_cast<float>(yolo_input_size_) * frame.rows;
        float w = width / static_cast<float>(yolo_input_size_) * frame.cols;
        float h = height / static_cast<float>(yolo_input_size_) * frame.rows;

        boxes.emplace_back(
            static_cast<int>(std::round(x)),
            static_cast<int>(std::round(y)),
            static_cast<int>(std::round(w)),
            static_cast<int>(std::round(h))
        );
        confidences.push_back(confidence);
    }

    std::vector<int> indices;
    cv::dnn::NMSBoxes(boxes, confidences, yolo_conf_threshold_, yolo_nms_threshold_, indices, 1.0f, 0);

    if (indices.empty()) {
        return cv::Rect();
    }

    cv::Rect best_box = clampRectToFrame(boxes[indices[0]], frame.size());

    // Expand the rectangle to include full forehead and chin
    return expandFaceRect(best_box, frame.size());
}

std::string TrackingEngine::resolveYoloModelPath() const {
    namespace fs = std::filesystem;
    auto tryResolve = [](const fs::path& candidate) -> std::string {
        if (candidate.empty()) {
            return {};
        }
        try {
            if (fs::exists(candidate)) {
                return fs::weakly_canonical(candidate).string();
            }
        } catch (const fs::filesystem_error&) {
        }
        return {};
    };

    if (const char* env_path = std::getenv("EYETRACKING_YOLO_FACE_MODEL")) {
        if (auto resolved = tryResolve(fs::path(env_path)); !resolved.empty()) {
            return resolved;
        }
    }

#ifdef EYETRACKING_DEFAULT_YOLO_FACE_MODEL_PATH
    if (auto resolved = tryResolve(fs::path(EYETRACKING_DEFAULT_YOLO_FACE_MODEL_PATH)); !resolved.empty()) {
        return resolved;
    }
#endif

    // Build model filenames with variant support
    // Try yolo11{variant}.onnx first, then fall back to yolov5n-face.onnx
    std::vector<std::string> model_names;
    if (!yolo_model_variant_.empty()) {
        model_names.push_back("yolo11" + yolo_model_variant_ + ".onnx");
        model_names.push_back("yolo11" + yolo_model_variant_ + "-face.onnx");
    }
    model_names.push_back("yolov5n-face.onnx");  // Legacy fallback

    std::vector<std::string> base_paths = {
        "../Resources/",
        "../../Resources/",
        "Resources/",
        "./",
        "core/models/",
        "../core/models/",
        "../../core/models/",
        "/usr/local/share/eyeball_tracking/models/",
        "/usr/share/eyeball_tracking/models/"
    };

    // Try all combinations of model names and base paths
    for (const auto& model_name : model_names) {
        for (const auto& base_path : base_paths) {
            if (auto resolved = tryResolve(fs::path(base_path + model_name)); !resolved.empty()) {
                return resolved;
            }
        }
    }

    return {};
}

TrackingEngine::FaceDetectorBackend TrackingEngine::parseFaceDetectorBackend(const std::string& value) {
    std::string lower;
    lower.resize(value.size());
    std::transform(value.begin(), value.end(), lower.begin(), [](unsigned char c) {
        return static_cast<char>(std::tolower(c));
    });

    if (lower == "yolo" || lower == "yolov5" || lower == "yolov8") {
        return FaceDetectorBackend::YOLO;
    }
    if (lower == "yunet") {
        return FaceDetectorBackend::YuNet;
    }
    if (lower == "haar" || lower == "haarcascade") {
        return FaceDetectorBackend::HaarCascade;
    }
    return FaceDetectorBackend::Auto;
}

std::string TrackingEngine::backendName(FaceDetectorBackend backend) const {
    switch (backend) {
        case FaceDetectorBackend::YOLO:
            return "YOLO";
        case FaceDetectorBackend::YuNet:
            return "YuNet";
        case FaceDetectorBackend::HaarCascade:
            return "HaarCascade";
        case FaceDetectorBackend::Auto:
        default:
            return "Auto";
    }
}

void TrackingEngine::setFaceDetectorBackend(FaceDetectorBackend backend) {
    active_backend_ = backend;
    std::cout << "[Tracking] Face detector backend switched to "
              << backendName(active_backend_) << std::endl;
}

void TrackingEngine::setYoloModelVariant(const std::string& variant) {
    if (yolo_model_variant_ != variant) {
        yolo_model_variant_ = variant;
        // Reset YOLO loading state to force reload with new variant
        yolo_load_attempted_ = false;
        yolo_net_loaded_ = false;
        yolo_face_net_ = cv::dnn::Net();  // Clear the network
        std::cout << "[Tracking] YOLO model variant set to: " << variant << std::endl;
    }
}
