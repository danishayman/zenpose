"""
generate_pose_templates.py
==========================
Process a yoga-pose image dataset and produce a JSON file of **mean pose
vectors** that can be loaded by a Flutter (or any other) app for real-time
pose comparison.

Usage
-----
    python generate_pose_templates.py

Expected dataset layout
-----------------------
    dataset/
        WarriorII/
            img1.jpg
            img2.jpg
        Tree/
            img1.jpg
            img2.jpg

Output
------
    pose_templates.json   (in the working directory)

The normalisation pipeline is **identical** to the Flutter app's
PoseNormalizationService:
    1. Translate hip center to origin.
    2. Scale by torso length (shoulder-center → hip-center distance).
    3. Select 12 key joints and flatten to a 24-element 1-D vector.
"""

import json
import math
import os
import sys
from pathlib import Path

import cv2
import mediapipe as mp
import numpy as np

# ──────────────────────────────────────────────────────────────────────────────
# Configuration
# ──────────────────────────────────────────────────────────────────────────────

# Path to the root of the dataset (one subfolder per pose class).
DATASET_DIR = Path("dataset")

# Output file that will contain the mean pose vectors.
OUTPUT_FILE = Path("pose_templates.json")

# Minimum detection confidence for MediaPipe Pose.
# Images whose overall detection confidence falls below this are skipped.
MIN_DETECTION_CONFIDENCE = 0.5

# Minimum per-landmark visibility.  A landmark with visibility below this
# threshold is treated as unreliable, and the whole image is discarded.
MIN_LANDMARK_VISIBILITY = 0.5

# Minimum torso length (in normalised MediaPipe coordinates) below which the
# pose is considered degenerate and is discarded.  Mirrors the Flutter
# constant `_minTorsoLength`.
MIN_TORSO_LENGTH = 1e-6

# Valid image extensions to look for in each pose folder.
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}

# ──────────────────────────────────────────────────────────────────────────────
# Key-joint indices (BlazePose 33-landmark model)
# ──────────────────────────────────────────────────────────────────────────────
# These match PoseNormalizationService._keyJointIndices exactly.
#
# Order:
#   L Shoulder, R Shoulder, L Elbow, R Elbow, L Wrist, R Wrist,
#   L Hip, R Hip, L Knee, R Knee, L Ankle, R Ankle
KEY_JOINT_INDICES = [
    11,  # left shoulder
    12,  # right shoulder
    13,  # left elbow
    14,  # right elbow
    15,  # left wrist
    16,  # right wrist
    23,  # left hip
    24,  # right hip
    25,  # left knee
    26,  # right knee
    27,  # left ankle
    28,  # right ankle
]

KEY_JOINT_LABELS = [
    "L Shoulder", "R Shoulder",
    "L Elbow",    "R Elbow",
    "L Wrist",    "R Wrist",
    "L Hip",      "R Hip",
    "L Knee",     "R Knee",
    "L Ankle",    "R Ankle",
]

# Torso-anchor indices used for translation and scaling.
LEFT_SHOULDER_IDX  = 11
RIGHT_SHOULDER_IDX = 12
LEFT_HIP_IDX       = 23
RIGHT_HIP_IDX      = 24


# ──────────────────────────────────────────────────────────────────────────────
# Normalisation helpers
# ──────────────────────────────────────────────────────────────────────────────

def normalize_landmarks(landmarks) -> list[float] | None:
    """
    Convert 33 raw MediaPipe landmarks into a 24-element normalised vector.

    Pipeline (mirrors Flutter's PoseNormalizationService):
        1. Validate that all torso-anchor and key-joint landmarks are visible.
        2. Compute hip center = midpoint(left_hip, right_hip).
        3. Compute shoulder center = midpoint(left_shoulder, right_shoulder).
        4. Compute torso length = ‖shoulder_center − hip_center‖.
        5. For each key joint:
               translated = landmark − hip_center
               normalised = translated / torso_length
        6. Flatten to [x₁, y₁, x₂, y₂, …].

    Returns None if any quality check fails.
    """

    # ── Step 0: Retrieve torso anchors ────────────────────────────────────
    left_hip  = landmarks[LEFT_HIP_IDX]
    right_hip = landmarks[RIGHT_HIP_IDX]
    left_sh   = landmarks[LEFT_SHOULDER_IDX]
    right_sh  = landmarks[RIGHT_SHOULDER_IDX]

    # Check visibility of the four torso anchors.  If any is unreliable the
    # entire image is discarded — same guard as the Flutter code.
    for lm in (left_hip, right_hip, left_sh, right_sh):
        if lm.visibility < MIN_LANDMARK_VISIBILITY:
            return None

    # ── Step 1: Hip center (translation origin) ──────────────────────────
    hip_cx = (left_hip.x + right_hip.x) / 2.0
    hip_cy = (left_hip.y + right_hip.y) / 2.0

    # ── Step 2: Shoulder center & torso length (scale factor) ────────────
    sh_cx = (left_sh.x + right_sh.x) / 2.0
    sh_cy = (left_sh.y + right_sh.y) / 2.0

    dx = sh_cx - hip_cx
    dy = sh_cy - hip_cy
    torso_length = math.sqrt(dx * dx + dy * dy)

    # Guard: avoid division-by-zero when the person is barely visible.
    if torso_length < MIN_TORSO_LENGTH:
        return None

    # ── Step 3: Select key joints, translate, scale, flatten ─────────────
    vector: list[float] = []

    for idx in KEY_JOINT_INDICES:
        lm = landmarks[idx]

        # Discard the image if any key joint has low confidence.
        if lm.visibility < MIN_LANDMARK_VISIBILITY:
            return None

        # Translate: move origin to hip center.
        tx = lm.x - hip_cx
        ty = lm.y - hip_cy

        # Scale: divide by torso length for size invariance.
        vector.append(tx / torso_length)
        vector.append(ty / torso_length)

    return vector


# ──────────────────────────────────────────────────────────────────────────────
# Dataset processing
# ──────────────────────────────────────────────────────────────────────────────

def collect_image_paths(class_dir: Path) -> list[Path]:
    """Return sorted list of image files inside *class_dir*."""
    return sorted(
        p for p in class_dir.iterdir()
        if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS
    )


def process_dataset(dataset_dir: Path) -> dict:
    """
    Walk every subfolder in *dataset_dir*, extract and normalise pose
    vectors for each image, then compute the **mean vector** per class.

    Returns a dict ready to be serialised as JSON:
        {
            "WarriorII": {"meanVector": [...]},
            "Tree":      {"meanVector": [...]},
            ...
        }
    """

    # Initialise MediaPipe Pose once and reuse across all images.
    mp_pose = mp.solutions.pose
    pose = mp_pose.Pose(
        static_image_mode=True,              # optimised for single images
        model_complexity=2,                   # highest accuracy model
        min_detection_confidence=MIN_DETECTION_CONFIDENCE,
    )

    templates: dict = {}

    # Each subfolder is one pose class (e.g. "WarriorII", "Tree").
    class_dirs = sorted(
        d for d in dataset_dir.iterdir() if d.is_dir()
    )

    if not class_dirs:
        print(f"[ERROR] No subdirectories found in '{dataset_dir}'.")
        sys.exit(1)

    for class_dir in class_dirs:
        class_name = class_dir.name
        image_paths = collect_image_paths(class_dir)

        if not image_paths:
            print(f"[WARN]  '{class_name}' — no images found, skipping.")
            continue

        print(f"\n{'─' * 60}")
        print(f"Processing class: {class_name}  ({len(image_paths)} images)")
        print(f"{'─' * 60}")

        vectors: list[list[float]] = []

        for img_path in image_paths:
            # ── Read and convert the image ────────────────────────────────
            # MediaPipe expects RGB; OpenCV loads BGR by default.
            bgr = cv2.imread(str(img_path))
            if bgr is None:
                print(f"  [SKIP] Cannot read '{img_path.name}'")
                continue

            rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)

            # ── Run MediaPipe Pose detection ──────────────────────────────
            result = pose.process(rgb)

            if result.pose_landmarks is None:
                print(f"  [SKIP] No pose detected in '{img_path.name}'")
                continue

            # ── Normalise the landmarks ───────────────────────────────────
            vec = normalize_landmarks(result.pose_landmarks.landmark)

            if vec is None:
                print(f"  [SKIP] Low-confidence landmarks in '{img_path.name}'")
                continue

            vectors.append(vec)
            print(f"  [OK]   '{img_path.name}' → {len(vec)}-element vector")

        # ── Compute the mean vector for this class ────────────────────────
        if not vectors:
            print(f"  [WARN] No valid vectors for '{class_name}', skipping.")
            continue

        # Stack into a NumPy matrix and average across rows.
        matrix = np.array(vectors)            # shape: (N, 24)
        mean_vector = matrix.mean(axis=0)     # shape: (24,)

        # Round for readability (6 decimal places).
        mean_list = [round(float(v), 6) for v in mean_vector]

        templates[class_name] = {"meanVector": mean_list}

        print(f"\n  ✓ {class_name}: used {len(vectors)}/{len(image_paths)} "
              f"images → mean vector ({len(mean_list)} elements)")

    pose.close()
    return templates


# ──────────────────────────────────────────────────────────────────────────────
# Main entry point
# ──────────────────────────────────────────────────────────────────────────────

def main():
    print("=" * 60)
    print("  Yoga Pose Template Generator")
    print("=" * 60)

    # ── Validate dataset directory ────────────────────────────────────────
    if not DATASET_DIR.is_dir():
        print(f"\n[ERROR] Dataset directory '{DATASET_DIR}' not found.")
        print("        Create it with one subfolder per pose class,")
        print("        each containing the reference images.")
        sys.exit(1)

    # ── Process every pose class ──────────────────────────────────────────
    templates = process_dataset(DATASET_DIR)

    if not templates:
        print("\n[ERROR] No pose templates were generated.")
        sys.exit(1)

    # ── Write the output JSON ─────────────────────────────────────────────
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        json.dump(templates, f, indent=2)

    print(f"\n{'=' * 60}")
    print(f"  Done!  {len(templates)} template(s) saved to '{OUTPUT_FILE}'")
    print(f"{'=' * 60}")

    # ── Print a summary table ─────────────────────────────────────────────
    print(f"\n{'Class':<20} {'Vector length':<15}")
    print(f"{'─' * 20} {'─' * 15}")
    for cls, data in templates.items():
        print(f"{cls:<20} {len(data['meanVector']):<15}")


if __name__ == "__main__":
    main()
