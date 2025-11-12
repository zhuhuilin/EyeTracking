#ifndef TRACKING_ENGINE_H
#define TRACKING_ENGINE_H

#include <opencv2/opencv.hpp>
#include <opencv2/core/version.hpp>
#include <opencv2/dnn.hpp>
#include <vector>
#include <string>
#include <optional>

#ifndef EYETRACKING_HAS_YUNET
#if (CV_VERSION_MAJOR > 4) || (CV_VERSION_MAJOR == 4 && CV_VERSION_MINOR >= 6)
#define EYETRACKING_HAS_YUNET 1
#else
#define EYETRACKING_HAS_YUNET 0
#endif
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
    cv::dnn::Net yolo_face_net_;
    bool yolo_load_attempted_;
    bool yolo_net_loaded_;
    float yolo_conf_threshold_;
    float yolo_nms_threshold_;
    int yolo_input_size_;
    std::string yolo_model_variant_;  // "n", "s", "m", "l", "x" or empty for default
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
