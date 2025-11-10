#ifndef TRACKING_ENGINE_H
#define TRACKING_ENGINE_H

#include <opencv2/opencv.hpp>
#include <vector>

struct TrackingResult {
    double face_distance;
    double gaze_angle_x;
    double gaze_angle_y;
    bool eyes_focused;
    bool head_moving;
    bool shoulders_moving;
};

class TrackingEngine {
public:
    TrackingEngine();
    ~TrackingEngine();

    // Initialize the tracking engine
    bool initialize();

    // Process a frame and return tracking results
    TrackingResult processFrame(const cv::Mat& frame);

    // Calibration methods
    void startCalibration();
    void addCalibrationPoint(const cv::Point2f& point);
    void finishCalibration();

    // Utility methods
    bool isCalibrated() const { return calibrated_; }
    void setCameraParameters(double focal_length, const cv::Point2f& principal_point);

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

    // Camera parameters
    double focal_length_;
    cv::Point2f principal_point_;
    
    // State tracking
    bool calibrated_;
    cv::Vec3f previous_head_pose_;
    std::vector<cv::Point2f> previous_shoulder_points_;
    
    // Calibration data
    std::vector<cv::Point2f> calibration_points_;
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
    };

    void* create_tracking_engine();
    void destroy_tracking_engine(void* engine);
    bool initialize_tracking_engine(void* engine);
    CTrackingResult process_frame(void* engine, unsigned char* frame_data, int width, int height);
    void set_camera_parameters(void* engine, double focal_length, double principal_x, double principal_y);
}

#endif // TRACKING_ENGINE_H
