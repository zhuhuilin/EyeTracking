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
} CTrackingResult;

void* create_tracking_engine(void);
void destroy_tracking_engine(void* engine);
bool initialize_tracking_engine(void* engine);
CTrackingResult process_frame(void* engine, unsigned char* frame_data, int width, int height);
void set_camera_parameters(void* engine, double focal_length, double principal_x, double principal_y);

#ifdef __cplusplus
}
#endif

#endif /* TRACKING_ENGINE_BRIDGE_H */
