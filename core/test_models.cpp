#include "include/tracking_engine.h"
#include <iostream>
#include <opencv2/opencv.hpp>

int main() {
    std::cout << "=== Eye Tracking Model Test ===" << std::endl;
    std::cout << "OpenCV version: " << CV_VERSION << std::endl;
    std::cout << std::endl;

    // Create tracking engine
    TrackingEngine engine;
    if (!engine.initialize()) {
        std::cerr << "Failed to initialize tracking engine" << std::endl;
        return 1;
    }

    // Create a test image (black image with a white rectangle simulating a face)
    cv::Mat test_frame(480, 640, CV_8UC3, cv::Scalar(50, 50, 50));
    cv::rectangle(test_frame, cv::Point(200, 150), cv::Point(400, 350), cv::Scalar(200, 180, 160), -1);
    cv::circle(test_frame, cv::Point(280, 220), 15, cv::Scalar(255, 255, 255), -1); // Left eye
    cv::circle(test_frame, cv::Point(360, 220), 15, cv::Scalar(255, 255, 255), -1); // Right eye
    cv::ellipse(test_frame, cv::Point(320, 290), cv::Size(40, 20), 0, 0, 180, cv::Scalar(220, 100, 100), 2); // Mouth

    std::cout << "Testing face detection backends..." << std::endl;
    std::cout << std::endl;

    // Test YOLO backend
    std::cout << "1. Testing YOLO backend:" << std::endl;
    engine.setFaceDetectorBackend(TrackingEngine::FaceDetectorBackend::YOLO);
    TrackingResult result_yolo = engine.processFrame(test_frame);
    if (result_yolo.face_detected) {
        std::cout << "   ✓ YOLO: Face detected successfully" << std::endl;
        std::cout << "     Face size: " << result_yolo.face_rect_width << "x" << result_yolo.face_rect_height << std::endl;
    } else {
        std::cout << "   ✗ YOLO: No face detected (model may not be available - this is optional)" << std::endl;
    }
    std::cout << std::endl;

    // Test YuNet backend
    std::cout << "2. Testing YuNet backend:" << std::endl;
    engine.setFaceDetectorBackend(TrackingEngine::FaceDetectorBackend::YuNet);
    TrackingResult result_yunet = engine.processFrame(test_frame);
    if (result_yunet.face_detected) {
        std::cout << "   ✓ YuNet: Face detected successfully" << std::endl;
        std::cout << "     Face size: " << result_yunet.face_rect_width << "x" << result_yunet.face_rect_height << std::endl;
    } else {
        std::cout << "   ✗ YuNet: No face detected (check model path)" << std::endl;
    }
    std::cout << std::endl;

    // Test Haar Cascade backend
    std::cout << "3. Testing Haar Cascade backend:" << std::endl;
    engine.setFaceDetectorBackend(TrackingEngine::FaceDetectorBackend::HaarCascade);
    TrackingResult result_haar = engine.processFrame(test_frame);
    if (result_haar.face_detected) {
        std::cout << "   ✓ Haar Cascade: Face detected successfully" << std::endl;
        std::cout << "     Face size: " << result_haar.face_rect_width << "x" << result_haar.face_rect_height << std::endl;
    } else {
        std::cout << "   ✗ Haar Cascade: No face detected (check cascade path)" << std::endl;
    }
    std::cout << std::endl;

    // Test Auto backend (priority: YOLO > YuNet > Haar Cascade)
    std::cout << "4. Testing Auto backend (with fallback):" << std::endl;
    engine.setFaceDetectorBackend(TrackingEngine::FaceDetectorBackend::Auto);
    TrackingResult result_auto = engine.processFrame(test_frame);
    if (result_auto.face_detected) {
        std::cout << "   ✓ Auto: Face detected successfully using fallback chain" << std::endl;
        std::cout << "     Face size: " << result_auto.face_rect_width << "x" << result_auto.face_rect_height << std::endl;
    } else {
        std::cout << "   ✗ Auto: No face detected with any backend" << std::endl;
    }
    std::cout << std::endl;

    // Summary
    std::cout << "=== Summary ===" << std::endl;
    int working_backends = 0;
    if (result_yolo.face_detected) working_backends++;
    if (result_yunet.face_detected) working_backends++;
    if (result_haar.face_detected) working_backends++;

    std::cout << "Working backends: " << working_backends << "/3" << std::endl;

    if (working_backends == 0) {
        std::cout << "✗ ERROR: No face detection backends are working!" << std::endl;
        std::cout << "  Please check that model files are in the correct location." << std::endl;
        return 1;
    } else if (working_backends < 3) {
        std::cout << "⚠ WARNING: Some backends are not working, but fallback is available." << std::endl;
        std::cout << "  The application will work but may have reduced performance." << std::endl;
    } else {
        std::cout << "✓ SUCCESS: All face detection backends are working!" << std::endl;
    }

    return 0;
}
