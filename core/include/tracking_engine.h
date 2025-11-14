#ifndef TRACKING_ENGINE_H
#define TRACKING_ENGINE_H

#include <opencv2/opencv.hpp>
#include <opencv2/core/version.hpp>
#include <vector>
#include <string>
#include <optional>

// Check if DNN module is available
#ifndef EYETRACKING_HAS_DNN
#ifdef HAVE_OPENCV_DNN
#define EYETRACKING_HAS_DNN 1
#include <opencv2/dnn.hpp>
#else
#define EYETRACKING_HAS_DNN 0
#endif
#endif

#ifndef EYETRACKING_HAS_YUNET
#if (CV_VERSION_MAJOR > 4) || (CV_VERSION_MAJOR == 4 && CV_VERSION_MINOR >= 6)
#define EYETRACKING_HAS_YUNET 1
#else
#define EYETRACKING_HAS_YUNET 0
#endif
#endif

#ifndef EYETRACKING_HAS_ONNXRUNTIME
#define EYETRACKING_HAS_ONNXRUNTIME 0
#endif

#if EYETRACKING_HAS_ONNXRUNTIME
#include <onnxruntime_cxx_api.h>
#include <memory>
#endif

struct TrackingResult {
    double face_distance;
    double gaze_angle_x;
    double gaze_angle_y;
    bool eyes_focused;
    bool head_moving;
    bool shoulders_moving;
    bool face_detected;
    double face_rect_x;
    double face_rect_y;
    double face_rect_width;
    double face_rect_height;

    // Extended tracking data for calibration
    // Face landmarks (68 points, dlib-style)
    std::vector<cv::Point2f> face_landmarks;

    // Head pose in degrees (pitch, yaw, roll)
    double head_pose_pitch;
    double head_pose_yaw;
    double head_pose_roll;

    // Gaze vector (normalized direction)
    double gaze_vector_x;
    double gaze_vector_y;
    double gaze_vector_z;

    // Detection confidence (0.0 to 1.0)
    double confidence;
};

class TrackingEngine {
public:
    enum class FaceDetectorBackend {
        Auto = 0,
        YOLO = 1,
        YuNet = 2,
        HaarCascade = 3
    };

    TrackingEngine();
    ~TrackingEngine();

    // Initialize the tracking engine
    bool initialize();

    // Process a frame and return tracking results
    TrackingResult processFrame(const cv::Mat& frame, std::optional<cv::Rect> override_face = std::nullopt);

    // Calibration methods
    void startCalibration();
    void addCalibrationPoint(const cv::Point2f& point);
    void finishCalibration();

    // Utility methods
    bool isCalibrated() const { return calibrated_; }
    void setCameraParameters(double focal_length, const cv::Point2f& principal_point);
    void setFaceDetectorBackend(FaceDetectorBackend backend);
    FaceDetectorBackend faceDetectorBackend() const { return active_backend_; }

    // Model variant selection
    void setYoloModelVariant(const std::string& variant);
    std::string getYoloModelVariant() const { return yolo_model_variant_; }

private:
    // Face detection and distance calculation
    cv::Rect detectFace(const cv::Mat& frame);
    double calculateFaceDistance(const cv::Rect& face_roi);
    std::vector<cv::Point2f> detectFaceLandmarks(const cv::Mat& frame, const cv::Rect& face_roi);

    // Eye tracking and gaze estimation
    std::vector<cv::Point2f> detectEyes(const cv::Mat& face_roi);
    cv::Point2f estimateGaze(const std::vector<cv::Point2f>& eye_points);

    // Head pose estimation
    cv::Vec3f estimateHeadPose(const std::vector<cv::Point2f>& face_points);
    bool detectHeadMovement(const cv::Vec3f& current_pose, const cv::Vec3f& previous_pose);

    // Shoulder movement detection
    std::vector<cv::Point2f> detectShoulders(const cv::Mat& frame);
    bool detectShoulderMovement(const std::vector<cv::Point2f>& current_points, 
                               const std::vector<cv::Point2f>& previous_points);
    cv::Rect detectFaceWithYuNet(const cv::Mat& frame);
    cv::Rect detectFaceWithCascade(const cv::Mat& frame);
    cv::Rect detectFaceWithYolo(const cv::Mat& frame);
    bool ensureFaceDetector();
    bool ensureCascadeClassifier();
    bool ensureYoloFaceNet();
    bool ensureYoloSession();
    std::string resolveFaceModelPath() const;
    std::string resolveYoloModelPath() const;
    static cv::Rect clampRectToFrame(const cv::Rect& rect, const cv::Size& size);
    static cv::Rect expandFaceRect(const cv::Rect& face_rect, const cv::Size& frame_size);
    static FaceDetectorBackend parseFaceDetectorBackend(const std::string& value);
    std::string backendName(FaceDetectorBackend backend) const;

    // Camera parameters
    double focal_length_;
    cv::Point2f principal_point_;
    float face_detection_score_threshold_;
    
    // State tracking
    bool calibrated_;
    cv::Vec3f previous_head_pose_;
    std::vector<cv::Point2f> previous_shoulder_points_;
    
    // Calibration data
    std::vector<cv::Point2f> calibration_points_;

#if EYETRACKING_HAS_YUNET
    cv::Ptr<cv::FaceDetectorYN> yunet_face_detector_;
#endif
    cv::CascadeClassifier fallback_face_cascade_;
    bool face_detector_load_attempted_;
    bool cascade_load_attempted_;
    FaceDetectorBackend active_backend_;
#if EYETRACKING_HAS_DNN
    cv::dnn::Net yolo_face_net_;
    bool yolo_load_attempted_;
    bool yolo_net_loaded_;
    float yolo_conf_threshold_;
    float yolo_nms_threshold_;
    int yolo_input_size_;
    std::string yolo_model_variant_;  // "n", "s", "m", "l", "x" or empty for default
#endif
#if EYETRACKING_HAS_ONNXRUNTIME
    std::unique_ptr<Ort::Env> ort_env_;
    std::unique_ptr<Ort::Session> yolo_session_;
    bool yolo_session_loaded_;
#endif
};

// C interface for Flutter integration
extern "C" {
    struct CTrackingResult {
        double face_distance;
        double gaze_angle_x;
        double gaze_angle_y;
        bool eyes_focused;
        bool head_moving;
        bool shoulders_moving;
        bool face_detected;
        double face_rect_x;
        double face_rect_y;
        double face_rect_width;
        double face_rect_height;

        // Extended tracking data
        // Face landmarks (68 points × 2 coordinates)
        float* face_landmarks;      // Array of x,y pairs
        int face_landmarks_count;   // Number of points (should be 68)

        // Head pose (pitch, yaw, roll in degrees)
        double head_pose_pitch;
        double head_pose_yaw;
        double head_pose_roll;

        // Gaze vector (normalized)
        double gaze_vector_x;
        double gaze_vector_y;
        double gaze_vector_z;

        // Detection confidence
        double confidence;
    };

    void* create_tracking_engine();
    void destroy_tracking_engine(void* engine);
    bool initialize_tracking_engine(void* engine);
    CTrackingResult process_frame(void* engine, unsigned char* frame_data, int width, int height);
    CTrackingResult process_frame_with_override(void* engine,
                                                unsigned char* frame_data,
                                                int width,
                                                int height,
                                                bool has_override,
                                                float norm_x,
                                                float norm_y,
                                                float norm_width,
                                                float norm_height);
    void set_camera_parameters(void* engine, double focal_length, double principal_x, double principal_y);
    void set_face_detector_backend(void* engine, int backend);
    void set_yolo_model_variant(void* engine, const char* variant);
}

#endif // TRACKING_ENGINE_H
