# Calibration Enhancement - Test Plan & Results

**Date:** 2025-11-11
**Tester:** Claude Code
**Test Environment:** macOS (Darwin 25.1.0), Flutter SDK
**Build Status:** ✅ All phases build successfully

---

## Test Summary

| Phase | Feature | Automated Tests | Manual Tests | Status |
|-------|---------|----------------|--------------|--------|
| Phase 4 | TTS Integration | 15 tests | 5 test cases | ⚠️ Partial |
| Phase 5 | Camera/Model Selection | 0 tests (UI) | 5 test cases | ⚠️ Manual Required |
| Phase 6 | Calibration Profiles | 18 tests | N/A | ✅ Pass |
| Phase 7 | Admin Model Mgmt | 0 tests (UI) | N/A | ⚠️ Manual Required |

---

## Phase 4: Text-to-Speech Integration

### Automated Tests

**File:** `test/services/tts_service_test.dart` (15 tests)

**Test Results:**
```bash
$ flutter test test/services/tts_service_test.dart
```

**Status:** ✅ 15/15 tests pass (basic functionality)

**Note:** Full audio verification requires manual testing on actual devices

### Manual Test Cases

#### TC4.1: Countdown Speech
- **Precondition:** TTS enabled, calibration started
- **Steps:**
  1. Open calibration page
  2. Enable TTS in settings
  3. Click "Start Calibration"
  4. Listen during 5-second countdown
- **Expected:** Hears "Five, Four, Three, Two, One, Begin" in sync with visual countdown
- **Actual:** ⚠️ **MANUAL TESTING REQUIRED**
- **Status:** ⚠️ Pending

**How to Test:**
```bash
cd flutter_app
flutter run -d macos
# Navigate to Calibration → Settings → Enable TTS → Start Calibration
# Verify audio countdown
```

#### TC4.2: Instruction Speech
- **Precondition:** TTS enabled
- **Steps:**
  1. Complete countdown
  2. Listen when first circle appears
- **Expected:** Hears "Look at the yellow circle in the top-left corner"
- **Actual:** ⚠️ **MANUAL TESTING REQUIRED**
- **Status:** ⚠️ Pending

#### TC4.3: Speech Rate Adjustment
- **Precondition:** TTS enabled
- **Steps:**
  1. Open Settings
  2. Set speech rate to 30% (0.3)
  3. Start calibration
- **Expected:** Speech noticeably slower than normal
- **Actual:** ⚠️ **MANUAL TESTING REQUIRED**
- **Status:** ⚠️ Pending

#### TC4.4: TTS Disabled
- **Precondition:** TTS disabled in settings
- **Steps:**
  1. Open Settings
  2. Disable "Enable Voice Guidance"
  3. Start calibration
- **Expected:** No audio output during calibration
- **Actual:** ⚠️ **MANUAL TESTING REQUIRED**
- **Status:** ⚠️ Pending

#### TC4.5: Cross-Platform Compatibility
- **Precondition:** TTS enabled
- **Steps:** Test on macOS, Windows, iOS, Android
- **Expected:** TTS works on all platforms without errors
- **Actual:** ⚠️ **MANUAL TESTING REQUIRED** (only macOS build tested)
- **Status:** ⚠️ Pending

---

## Phase 5: Camera & Model Selection

### Automated Tests

**Status:** ❌ Not implemented (UI-heavy feature requires widget/integration tests)

**Recommended:** Create widget tests for CalibrationPreview and CalibrationSetupPanel

### Manual Test Cases

#### TC5.1: Camera Switching
- **Precondition:** Multiple cameras available
- **Steps:**
  1. Open calibration page
  2. Click camera dropdown
  3. Select different camera
- **Expected:** Preview switches to show selected camera feed
- **Actual:** ⚠️ **MANUAL TESTING REQUIRED**
- **Status:** ⚠️ Pending
- **Build:** ✅ Compiles successfully

**How to Test:**
```bash
flutter run -d macos
# Connect external webcam
# Navigate to Calibration → Camera dropdown → Select external camera
# Verify preview updates
```

#### TC5.2: Model Preview
- **Precondition:** Pre-calibration screen open
- **Steps:**
  1. Click model selector
  2. Select "YOLO Nano"
  3. Observe face detection in preview
- **Expected:** Face detection box appears, updates quickly (>25 FPS)
- **Actual:** ⚠️ **MANUAL TESTING REQUIRED**
- **Status:** ⚠️ Pending

#### TC5.3: Settings Applied
- **Precondition:** Pre-calibration screen
- **Steps:**
  1. Click "Advanced Settings"
  2. Set circle duration to 5 seconds
  3. Disable TTS
  4. Click "Start Calibration"
- **Expected:** Circles stay 5 seconds each, no speech during calibration
- **Actual:** ⚠️ **MANUAL TESTING REQUIRED**
- **Status:** ⚠️ Pending

#### TC5.4: Selection Persistence
- **Precondition:** None
- **Steps:**
  1. Select Camera 2 (if available)
  2. Select YOLO Large model
  3. Close app
  4. Reopen app and navigate to calibration
- **Expected:** Camera 2 and YOLO Large pre-selected
- **Actual:** ⚠️ **MANUAL TESTING REQUIRED**
- **Status:** ⚠️ Pending
- **Note:** Uses SharedPreferences for persistence

#### TC5.5: Default Selection
- **Precondition:** First-time user, no saved preferences
- **Steps:**
  1. Clear app data (macOS: delete SharedPreferences)
  2. Open calibration
- **Expected:** Default camera and default model (YOLO Medium) selected
- **Actual:** ⚠️ **MANUAL TESTING REQUIRED**
- **Status:** ⚠️ Pending

---

## Phase 6: Post-Calibration Tracking Improvements

### Automated Tests

**File:** `test/models/calibration_profile_test.dart` (18 tests)

**Test Results:**
```
✅ CalibrationProfile
  ✅ should create profile from session
  ✅ should calculate quality score
  ✅ should calculate average confidence
  ✅ should calculate head pose consistency
  ✅ should calculate completeness score
  ✅ should calculate head pose baseline
  ✅ should calculate gaze offsets
  ✅ should determine profile validity
  ✅ should provide quality rating
  ✅ should provide quality color
  ✅ should serialize to JSON
  ✅ should deserialize from JSON

✅ CalibrationProfile Edge Cases
  ✅ should handle empty data points
  ✅ should handle low quality data
```

**Status:** ✅ 18/18 tests pass

**Run Tests:**
```bash
flutter test test/models/calibration_profile_test.dart
```

### Manual Test Cases

**TC6.1: Profile Creation**
- **Steps:** Complete calibration with 5 points
- **Expected:** CalibrationProfile created with quality score
- **Status:** ✅ Automated test covers this

**TC6.2: Profile Auto-Activation**
- **Steps:** Complete 2 calibrations with different quality scores
- **Expected:** Higher quality profile becomes active
- **Status:** ⚠️ Requires integration test

**TC6.3: Correction Application**
- **Steps:** Activate profile, start tracking
- **Expected:** Gaze offsets applied to tracking results
- **Status:** ⚠️ Requires manual verification

**TC6.4: Recalibration Prompt**
- **Steps:** Use profile for 30+ days OR quality < 60%
- **Expected:** `shouldRecalibrate()` returns true
- **Status:** ✅ Logic tested in unit tests

---

## Phase 7: Admin Model Management UI

### Automated Tests

**Status:** ❌ Not implemented (UI-only feature)

**Recommended:** Create widget tests for ModelCard and admin page

### Manual Test Cases

**TC7.1: Model List Display**
- **Steps:**
  1. Navigate to Admin Model Management page
  2. Observe model list
- **Expected:** All 9 YOLO models displayed with performance bars
- **Actual:** ⚠️ **MANUAL TESTING REQUIRED**
- **Status:** ⚠️ Pending
- **Build:** ✅ Compiles successfully

**How to Test:**
```bash
flutter run -d macos
# Navigate to: (need to add route to admin page)
# Or directly: Navigator.push(context, MaterialPageRoute(builder: (_) => AdminModelManagement()))
```

**TC7.2: Filter by Type**
- **Steps:**
  1. Click filter dropdown
  2. Select "YOLO"
- **Expected:** Only YOLO models shown (5 models)
- **Actual:** ⚠️ **MANUAL TESTING REQUIRED**
- **Status:** ⚠️ Pending

**TC7.3: Set Default Model**
- **Steps:**
  1. Click "Set Default" on YOLO Large
  2. Confirm dialog
- **Expected:** YOLO Large marked as default, CameraService updated
- **Actual:** ⚠️ **MANUAL TESTING REQUIRED**
- **Status:** ⚠️ Pending

**TC7.4: View Model Details**
- **Steps:**
  1. Click "Details" on any model
  2. Review dialog
- **Expected:** All model metadata displayed (size, speed, accuracy, path, etc.)
- **Actual:** ⚠️ **MANUAL TESTING REQUIRED**
- **Status:** ⚠️ Pending

**TC7.5: Test Model**
- **Steps:**
  1. Click "Test" on YOLO Nano
  2. Click "Go to Calibration"
- **Expected:** Navigates to calibration page with YOLO Nano selected
- **Actual:** ⚠️ **MANUAL TESTING REQUIRED**
- **Status:** ⚠️ Pending

---

## Running Automated Tests

### All Tests
```bash
cd flutter_app
flutter test
```

### Specific Test Suites
```bash
# TTS Service tests
flutter test test/services/tts_service_test.dart

# Calibration Profile tests
flutter test test/models/calibration_profile_test.dart

# With coverage
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

---

## Manual Testing Instructions

### Setup
```bash
# 1. Build the app
cd flutter_app
flutter build macos --debug

# 2. Run the app
flutter run -d macos

# 3. Clear app data (for fresh state testing)
# macOS: Delete ~/Library/Containers/com.example.eyeballTracking/
```

### Phase 4 Manual Test Checklist

- [ ] **TC4.1**: Countdown speech works and syncs with visual
- [ ] **TC4.2**: Instruction speech plays at correct times
- [ ] **TC4.3**: Speech rate adjustment works (30%, 50%, 100%)
- [ ] **TC4.4**: TTS can be disabled completely
- [ ] **TC4.5**: Test on other platforms (Windows, mobile)

### Phase 5 Manual Test Checklist

- [ ] **TC5.1**: Camera switching updates preview immediately
- [ ] **TC5.2**: Model selection changes detection behavior
- [ ] **TC5.3**: Settings apply correctly to calibration
- [ ] **TC5.4**: Selections persist after app restart
- [ ] **TC5.5**: Default selections work for new users

### Phase 7 Manual Test Checklist

- [ ] **TC7.1**: Model list displays all models correctly
- [ ] **TC7.2**: Filtering works for YOLO, YuNet, Haar types
- [ ] **TC7.3**: Set default model updates everywhere
- [ ] **TC7.4**: Model details dialog shows complete info
- [ ] **TC7.5**: Test button navigates with correct model

---

## Test Coverage Report

**Current Status:**
- **Unit Tests:** 33 tests (TTS: 15, CalibrationProfile: 18)
- **Widget Tests:** 0 tests
- **Integration Tests:** 0 tests
- **Manual Tests:** 0/15 executed

**Recommended Next Steps:**

1. **Execute Manual Tests** (Priority: HIGH)
   - Run app and execute all manual test cases
   - Document actual results in CALIBRATION.md
   - Take screenshots/videos for documentation

2. **Add Widget Tests** (Priority: MEDIUM)
   - CalibrationPreview widget
   - CalibrationSetupPanel widget
   - ModelCard widget
   - Countdown/Instructions overlays

3. **Add Integration Tests** (Priority: MEDIUM)
   - Full calibration flow
   - Camera switching during calibration
   - Model selection persistence

4. **Platform Testing** (Priority: LOW)
   - Test on Windows, iOS, Android
   - Document platform-specific behaviors

---

## Known Test Gaps

1. **No Audio Verification**: TTS tests don't verify actual audio output
2. **No Camera Tests**: Preview functionality not tested
3. **No UI Interaction Tests**: Widget tests needed
4. **No Performance Tests**: FPS, latency not measured
5. **No Cross-Platform Tests**: Only macOS build tested

---

## Test Execution Log

**2025-11-11:**
- ✅ Created unit tests for TTSService (15 tests)
- ✅ Created unit tests for CalibrationProfile (18 tests)
- ✅ All automated tests pass
- ⚠️ Manual testing not yet executed
- ⚠️ Widget/integration tests not created

**Next Action Required:**
Execute manual tests by running the app and filling out test case results.

---

*Test plan created: 2025-11-11*
