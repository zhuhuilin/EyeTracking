#include "include/tracking_engine.h"
#include <iostream>
#include <opencv2/opencv.hpp>

int main(int argc, char** argv) {
    std::cout << "=== Eye Tracking Model Test (Real Image) ===" << std::endl;
    std::cout << "OpenCV version: " << CV_VERSION << std::endl;
    std::cout << std::endl;

    // Load test image
    std::string image_path = argc > 1 ? argv[1] : "test_face.jpg";
    cv::Mat test_frame = cv::imread(image_path);

    if (test_frame.empty()) {
        std::cerr << "Failed to load image: " << image_path << std::endl;
        std::cerr << "Usage: " << argv[0] << " [image_path]" << std::endl;
        return 1;
    }

    std::cout << "Loaded image: " << image_path << std::endl;
    std::cout << "Image size: " << test_frame.cols << "x" << test_frame.rows << std::endl;
    std::cout << std::endl;

    // Create tracking engine
    TrackingEngine engine;
    if (!engine.initialize()) {
        std::cerr << "Failed to initialize tracking engine" << std::endl;
        return 1;
    }

    std::cout << "Testing face detection backends..." << std::endl;
    std::cout << std::endl;

    // Test YuNet backend
    std::cout << "1. Testing YuNet backend:" << std::endl;
    engine.setFaceDetectorBackend(TrackingEngine::FaceDetectorBackend::YuNet);
    TrackingResult result_yunet = engine.processFrame(test_frame);
    if (result_yunet.face_detected) {
        std::cout << "   ✓ YuNet: Face detected successfully" << std::endl;
        std::cout << "     Position: (" << result_yunet.face_rect_x << ", " << result_yunet.face_rect_y << ")" << std::endl;
        std::cout << "     Size: " << result_yunet.face_rect_width << "x" << result_yunet.face_rect_height << std::endl;
    } else {
        std::cout << "   ✗ YuNet: No face detected" << std::endl;
    }
    std::cout << std::endl;

    // Test Haar Cascade backend
    std::cout << "2. Testing Haar Cascade backend:" << std::endl;
    engine.setFaceDetectorBackend(TrackingEngine::FaceDetectorBackend::HaarCascade);
    TrackingResult result_haar = engine.processFrame(test_frame);
    if (result_haar.face_detected) {
        std::cout << "   ✓ Haar Cascade: Face detected successfully" << std::endl;
        std::cout << "     Position: (" << result_haar.face_rect_x << ", " << result_haar.face_rect_y << ")" << std::endl;
        std::cout << "     Size: " << result_haar.face_rect_width << "x" << result_haar.face_rect_height << std::endl;
    } else {
        std::cout << "   ✗ Haar Cascade: No face detected" << std::endl;
    }
    std::cout << std::endl;

    // Test Auto backend
    std::cout << "3. Testing Auto backend (with fallback):" << std::endl;
    engine.setFaceDetectorBackend(TrackingEngine::FaceDetectorBackend::Auto);
    TrackingResult result_auto = engine.processFrame(test_frame);
    if (result_auto.face_detected) {
        std::cout << "   ✓ Auto: Face detected successfully" << std::endl;
        std::cout << "     Position: (" << result_auto.face_rect_x << ", " << result_auto.face_rect_y << ")" << std::endl;
        std::cout << "     Size: " << result_auto.face_rect_width << "x" << result_auto.face_rect_height << std::endl;
        std::cout << "     Distance: " << result_auto.face_distance << " cm" << std::endl;
        std::cout << "     Gaze: (" << result_auto.gaze_angle_x << ", " << result_auto.gaze_angle_y << ")" << std::endl;
    } else {
        std::cout << "   ✗ Auto: No face detected" << std::endl;
    }
    std::cout << std::endl;

    // Summary
    std::cout << "=== Summary ===" << std::endl;
    int working_backends = 0;
    if (result_yunet.face_detected) working_backends++;
    if (result_haar.face_detected) working_backends++;

    std::cout << "Working backends: " << working_backends << "/2 (YOLO is optional)" << std::endl;

    if (working_backends == 0) {
        std::cout << "✗ ERROR: No face detection backends detected a face!" << std::endl;
        std::cout << "  This could mean:" << std::endl;
        std::cout << "  - The test image doesn't contain a clear face" << std::endl;
        std::cout << "  - Model files are corrupted" << std::endl;
        std::cout << "  - Detection parameters need adjustment" << std::endl;
        return 1;
    } else if (working_backends == 1) {
        std::cout << "⚠ WARNING: Only one backend detected a face." << std::endl;
        std::cout << "  The application will work with fallback." << std::endl;
    } else {
        std::cout << "✓ SUCCESS: Both YuNet and Haar Cascade are working!" << std::endl;
    }

    return 0;
}
