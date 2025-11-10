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
    cv::CascadeClassifier eye_cascade;
    std::vector<cv::Rect> eyes;

    if (eye_cascade.load("/usr/share/opencv4/haarcascades/haarcascade_eye.xml")) {
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
