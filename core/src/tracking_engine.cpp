#include "tracking_engine.h"
#include <opencv2/objdetect.hpp>
#include <opencv2/imgproc.hpp>
#include <cmath>
#include <iostream>

TrackingEngine::TrackingEngine() 
    : focal_length_(1000.0), 
      principal_point_(cv::Point2f(0, 0)),
      calibrated_(false) {
}

TrackingEngine::~TrackingEngine() {
}

bool TrackingEngine::initialize() {
    // Initialize face detector and other models
    // This would typically load Haar cascades or DNN models
    std::cout << "Tracking engine initialized" << std::endl;
    return true;
}

TrackingResult TrackingEngine::processFrame(const cv::Mat& frame) {
    TrackingResult result = {0};
    
    // Convert to grayscale for processing
    cv::Mat gray;
    if (frame.channels() == 3) {
        cv::cvtColor(frame, gray, cv::COLOR_BGR2GRAY);
    } else {
        gray = frame.clone();
    }
    
    // Face detection
    cv::Rect face_roi = detectFace(gray);
    if (face_roi.width > 0 && face_roi.height > 0) {
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
    // Simple face detection using Haar cascade (placeholder)
    // In production, this would use a more robust method like DNN or MediaPipe
    cv::CascadeClassifier face_cascade;
    std::vector<cv::Rect> faces;
    
    // Load pre-trained face detector (this path would be configured properly)
    if (face_cascade.load("/usr/share/opencv4/haarcascades/haarcascade_frontalface_default.xml")) {
        face_cascade.detectMultiScale(frame, faces, 1.1, 3, 0, cv::Size(30, 30));
    }
    
    if (!faces.empty()) {
        return faces[0]; // Return the largest face
    }
    
    return cv::Rect();
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
    
    // Simple eye detection using Haar cascade (placeholder)
    cv::CascadeClassifier eye_cascade;
    std::vector<cv::Rect> eyes;
    
    if (eye_cascade.load("/usr/share/opencv4/haarcascades/haarcascade_eye.xml")) {
        eye_cascade.detectMultiScale(face_roi, eyes, 1.1, 2, 0, cv::Size(30, 30));
    }
    
    // Convert eye positions to points
    for (const auto& eye : eyes) {
        cv::Point2f center(eye.x + eye.width/2.0f, eye.y + eye.height/2.0f);
        eye_points.push_back(center);
    }
    
    return eye_points;
}

cv::Point2f TrackingEngine::estimateGaze(const std::vector<cv::Point2f>& eye_points) {
    // Simple gaze estimation based on relative eye positions
    // In production, this would use more sophisticated methods
    if (eye_points.size() < 2) {
        return cv::Point2f(0, 0);
    }
    
    // Calculate center between eyes
    cv::Point2f center(0, 0);
    for (const auto& point : eye_points) {
        center += point;
    }
    center.x /= eye_points.size();
    center.y /= eye_points.size();
    
    // Simple gaze direction (placeholder)
    // This would be replaced with proper gaze estimation algorithms
    cv::Point2f gaze(0.0f, 0.0f);
    
    return gaze;
}

std::vector<cv::Point2f> TrackingEngine::detectFaceLandmarks(const cv::Mat& frame, const cv::Rect& face_roi) {
    std::vector<cv::Point2f> landmarks;
    
    // Placeholder for face landmark detection
    // In production, this would use Dlib, MediaPipe, or OpenCV's face module
    
    // Simple landmarks based on face rectangle
    landmarks.push_back(cv::Point2f(face_roi.x, face_roi.y)); // Top-left
    landmarks.push_back(cv::Point2f(face_roi.x + face_roi.width, face_roi.y)); // Top-right
    landmarks.push_back(cv::Point2f(face_roi.x + face_roi.width/2, face_roi.y + face_roi.height/2)); // Center
    landmarks.push_back(cv::Point2f(face_roi.x, face_roi.y + face_roi.height)); // Bottom-left
    landmarks.push_back(cv::Point2f(face_roi.x + face_roi.width, face_roi.y + face_roi.height)); // Bottom-right
    
    return landmarks;
}

cv::Vec3f TrackingEngine::estimateHeadPose(const std::vector<cv::Point2f>& face_points) {
    // Simple head pose estimation (placeholder)
    // In production, this would use solvePnP with a 3D face model
    
    cv::Vec3f pose(0, 0, 0); // pitch, yaw, roll
    
    if (face_points.size() >= 5) {
        // Calculate simple pose based on face landmark symmetry
        float left_right_diff = std::abs(face_points[0].x - face_points[1].x);
        float top_bottom_diff = std::abs(face_points[0].y - face_points[3].y);
        
        // Simplified pose estimation
        pose[1] = (face_points[0].x - face_points[1].x) / 100.0f; // Yaw
        pose[0] = (face_points[0].y - face_points[3].y) / 100.0f; // Pitch
    }
    
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
    
    // Placeholder for shoulder detection
    // In production, this would use pose estimation models like MediaPipe Pose
    
    // Simple shoulder points based on frame dimensions
    int frame_height = frame.rows;
    int frame_width = frame.cols;
    
    shoulder_points.push_back(cv::Point2f(frame_width * 0.25f, frame_height * 0.8f)); // Left shoulder
    shoulder_points.push_back(cv::Point2f(frame_width * 0.75f, frame_height * 0.8f)); // Right shoulder
    
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
        CTrackingResult c_result;
        c_result.face_distance = result.face_distance;
        c_result.gaze_angle_x = result.gaze_angle_x;
        c_result.gaze_angle_y = result.gaze_angle_y;
        c_result.eyes_focused = result.eyes_focused;
        c_result.head_moving = result.head_moving;
        c_result.shoulders_moving = result.shoulders_moving;
        
        return c_result;
    }
    
    void set_camera_parameters(void* engine, double focal_length, double principal_x, double principal_y) {
        TrackingEngine* tracking_engine = static_cast<TrackingEngine*>(engine);
        tracking_engine->setCameraParameters(focal_length, cv::Point2f(principal_x, principal_y));
    }
}
