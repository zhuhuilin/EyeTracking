#ifndef TRACKING_ENGINE_BRIDGE_H
#define TRACKING_ENGINE_BRIDGE_H

#include <stdbool.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
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
} CTrackingResult;

typedef enum {
    FACE_BACKEND_AUTO = 0,
    FACE_BACKEND_YOLO = 1,
    FACE_BACKEND_YUNET = 2,
    FACE_BACKEND_HAAR = 3
} FaceDetectorBackendC;

void* create_tracking_engine(void);
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

#ifdef __cplusplus
}
#endif

#endif /* TRACKING_ENGINE_BRIDGE_H */
