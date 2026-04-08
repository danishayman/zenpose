"""
generate_pose_templates.py
==========================
Generate pose templates from a labeled image dataset and evaluate them with a
held-out split before adoption into the app.

What this script does
---------------------
1. Scans a dataset folder where each subdirectory is a pose class.
2. Creates a deterministic train/validation/test split.
3. Extracts normalized 24-element pose vectors from each image.
4. Trains one template (mean vector) per class from TRAIN images only.
5. Evaluates classification performance on VALIDATION and TEST splits.
6. Writes:
   - templates JSON (for the Flutter app)
   - split manifest JSON (for reproducibility/audit)
   - evaluation report JSON (metrics + confusion matrix + gate result)

Expected dataset layout
-----------------------
dataset/
  chair/
    img1.jpg
    img2.jpg
  tree/
    img1.jpg
    ...
"""

from __future__ import annotations

import argparse
import json
import math
import random
import sys
from collections import defaultdict
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import cv2
import mediapipe as mp
import numpy as np

# ---------------------------------------------------------------------------
# Defaults / configuration
# ---------------------------------------------------------------------------

DEFAULT_DATASET_DIR = Path("dataset")
DEFAULT_OUTPUT_FILE = Path("assets/pose_templates.json")
DEFAULT_SPLIT_MANIFEST = Path("build/pose_eval/split_manifest.json")
DEFAULT_EVAL_REPORT = Path("build/pose_eval/evaluation_report.json")

MIN_DETECTION_CONFIDENCE = 0.5
MIN_LANDMARK_VISIBILITY = 0.5
MIN_TORSO_LENGTH = 1e-6
IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}

# Default quality gate (can be changed by CLI).
DEFAULT_MIN_VAL_MACRO_F1 = 0.80
DEFAULT_MIN_TEST_ACCURACY = 0.85
DEFAULT_MIN_TEST_MACRO_F1 = 0.85

# BlazePose 33-landmark model indices.
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

LEFT_SHOULDER_IDX = 11
RIGHT_SHOULDER_IDX = 12
LEFT_HIP_IDX = 23
RIGHT_HIP_IDX = 24

SPLITS = ("train", "validation", "test")


@dataclass(frozen=True)
class Sample:
    class_name: str
    relative_path: str
    split: str


@dataclass(frozen=True)
class ValidExample:
    class_name: str
    split: str
    relative_path: str
    vector: list[float]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Generate pose templates from training images and evaluate "
            "accuracy on held-out validation/test images."
        )
    )
    parser.add_argument(
        "--dataset-dir",
        type=Path,
        default=DEFAULT_DATASET_DIR,
        help=f"Dataset root directory (default: {DEFAULT_DATASET_DIR})",
    )
    parser.add_argument(
        "--output-file",
        type=Path,
        default=DEFAULT_OUTPUT_FILE,
        help=f"Template JSON output path (default: {DEFAULT_OUTPUT_FILE})",
    )
    parser.add_argument(
        "--split-manifest",
        type=Path,
        default=DEFAULT_SPLIT_MANIFEST,
        help=f"Split manifest JSON path (default: {DEFAULT_SPLIT_MANIFEST})",
    )
    parser.add_argument(
        "--report-file",
        type=Path,
        default=DEFAULT_EVAL_REPORT,
        help=f"Evaluation report JSON path (default: {DEFAULT_EVAL_REPORT})",
    )
    parser.add_argument(
        "--train-ratio",
        type=float,
        default=0.70,
        help="Train split ratio (default: 0.70)",
    )
    parser.add_argument(
        "--validation-ratio",
        type=float,
        default=0.15,
        help="Validation split ratio (default: 0.15)",
    )
    parser.add_argument(
        "--test-ratio",
        type=float,
        default=0.15,
        help="Test split ratio (default: 0.15)",
    )
    parser.add_argument(
        "--seed",
        type=int,
        default=42,
        help="Random seed for deterministic split assignment (default: 42)",
    )
    parser.add_argument(
        "--min-val-macro-f1",
        type=float,
        default=DEFAULT_MIN_VAL_MACRO_F1,
        help=f"Gate threshold for validation macro F1 (default: {DEFAULT_MIN_VAL_MACRO_F1})",
    )
    parser.add_argument(
        "--min-test-accuracy",
        type=float,
        default=DEFAULT_MIN_TEST_ACCURACY,
        help=f"Gate threshold for test accuracy (default: {DEFAULT_MIN_TEST_ACCURACY})",
    )
    parser.add_argument(
        "--min-test-macro-f1",
        type=float,
        default=DEFAULT_MIN_TEST_MACRO_F1,
        help=f"Gate threshold for test macro F1 (default: {DEFAULT_MIN_TEST_MACRO_F1})",
    )
    parser.add_argument(
        "--disable-gate",
        action="store_true",
        help="Disable quality gate failure exit code.",
    )
    return parser.parse_args()


def validate_split_ratios(train_ratio: float, validation_ratio: float, test_ratio: float) -> None:
    if train_ratio <= 0.0 or validation_ratio < 0.0 or test_ratio < 0.0:
        raise ValueError("Ratios must be non-negative and train ratio must be > 0.")
    total = train_ratio + validation_ratio + test_ratio
    if not math.isclose(total, 1.0, rel_tol=1e-6, abs_tol=1e-6):
        raise ValueError(
            f"Split ratios must sum to 1.0 (got {total:.6f}). "
            "Example: 0.7 0.15 0.15"
        )


def collect_image_paths(class_dir: Path) -> list[Path]:
    return sorted(
        path
        for path in class_dir.iterdir()
        if path.is_file() and path.suffix.lower() in IMAGE_EXTENSIONS
    )


def get_dataset_index(dataset_dir: Path) -> dict[str, list[Path]]:
    if not dataset_dir.is_dir():
        raise FileNotFoundError(f"Dataset directory '{dataset_dir}' not found.")

    class_dirs = sorted(path for path in dataset_dir.iterdir() if path.is_dir())
    if not class_dirs:
        raise RuntimeError(f"No class subdirectories found in '{dataset_dir}'.")

    class_to_images: dict[str, list[Path]] = {}
    for class_dir in class_dirs:
        image_paths = collect_image_paths(class_dir)
        if image_paths:
            class_to_images[class_dir.name] = image_paths

    if not class_to_images:
        raise RuntimeError(f"No image files found in '{dataset_dir}'.")
    return class_to_images


def split_counts_for_class(
    n: int,
    train_ratio: float,
    validation_ratio: float,
    test_ratio: float,
) -> tuple[int, int, int]:
    if n <= 0:
        return (0, 0, 0)
    if n == 1:
        return (1, 0, 0)
    if n == 2:
        return (1, 1, 0)

    raw = np.array([train_ratio, validation_ratio, test_ratio], dtype=float) * n
    counts = np.floor(raw).astype(int)
    remainder = n - int(counts.sum())

    if remainder > 0:
        fractional_order = np.argsort(-(raw - counts))
        for idx in fractional_order[:remainder]:
            counts[idx] += 1

    # Ensure each split gets at least one sample when possible.
    for idx in (0, 1, 2):
        if counts[idx] == 0:
            donor = int(np.argmax(counts))
            if counts[donor] > 1:
                counts[donor] -= 1
                counts[idx] += 1

    train_count, val_count, test_count = map(int, counts)
    # Keep train non-zero for template generation.
    if train_count == 0 and n > 0:
        train_count = 1
        if val_count > test_count and val_count > 0:
            val_count -= 1
        elif test_count > 0:
            test_count -= 1

    if train_count + val_count + test_count != n:
        # Safety fallback.
        test_count = n - train_count - val_count

    return (train_count, val_count, test_count)


def build_split_manifest(
    class_to_images: dict[str, list[Path]],
    dataset_dir: Path,
    train_ratio: float,
    validation_ratio: float,
    test_ratio: float,
    seed: int,
) -> list[Sample]:
    rng = random.Random(seed)
    samples: list[Sample] = []

    for class_name, image_paths in sorted(class_to_images.items()):
        shuffled = image_paths[:]
        rng.shuffle(shuffled)

        train_count, val_count, test_count = split_counts_for_class(
            n=len(shuffled),
            train_ratio=train_ratio,
            validation_ratio=validation_ratio,
            test_ratio=test_ratio,
        )

        boundaries = (
            train_count,
            train_count + val_count,
            train_count + val_count + test_count,
        )
        split_labels = (
            ["train"] * train_count
            + ["validation"] * val_count
            + ["test"] * test_count
        )

        if boundaries[2] != len(shuffled):
            raise RuntimeError(f"Split construction mismatch for class '{class_name}'.")

        for path, split in zip(shuffled, split_labels):
            rel_path = path.relative_to(dataset_dir).as_posix()
            samples.append(
                Sample(
                    class_name=class_name,
                    relative_path=rel_path,
                    split=split,
                )
            )

    return samples


def save_split_manifest(
    path: Path,
    samples: list[Sample],
    seed: int,
    train_ratio: float,
    validation_ratio: float,
    test_ratio: float,
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "createdAtUtc": datetime.now(timezone.utc).isoformat(),
        "seed": seed,
        "ratios": {
            "train": train_ratio,
            "validation": validation_ratio,
            "test": test_ratio,
        },
        "samples": [
            {
                "class": sample.class_name,
                "path": sample.relative_path,
                "split": sample.split,
            }
            for sample in samples
        ],
    }
    with path.open("w", encoding="utf-8") as file:
        json.dump(payload, file, indent=2)


def normalize_landmarks(landmarks: Any) -> list[float] | None:
    left_hip = landmarks[LEFT_HIP_IDX]
    right_hip = landmarks[RIGHT_HIP_IDX]
    left_sh = landmarks[LEFT_SHOULDER_IDX]
    right_sh = landmarks[RIGHT_SHOULDER_IDX]

    for landmark in (left_hip, right_hip, left_sh, right_sh):
        if landmark.visibility < MIN_LANDMARK_VISIBILITY:
            return None

    hip_cx = (left_hip.x + right_hip.x) / 2.0
    hip_cy = (left_hip.y + right_hip.y) / 2.0
    sh_cx = (left_sh.x + right_sh.x) / 2.0
    sh_cy = (left_sh.y + right_sh.y) / 2.0

    torso_dx = sh_cx - hip_cx
    torso_dy = sh_cy - hip_cy
    torso_length = math.sqrt(torso_dx * torso_dx + torso_dy * torso_dy)
    if torso_length < MIN_TORSO_LENGTH:
        return None

    vector: list[float] = []
    for idx in KEY_JOINT_INDICES:
        landmark = landmarks[idx]
        if landmark.visibility < MIN_LANDMARK_VISIBILITY:
            return None
        vector.append((landmark.x - hip_cx) / torso_length)
        vector.append((landmark.y - hip_cy) / torso_length)

    return vector


def extract_valid_examples(
    dataset_dir: Path,
    samples: list[Sample],
) -> tuple[list[ValidExample], dict[str, Any]]:
    mp_pose = mp.solutions.pose
    pose = mp_pose.Pose(
        static_image_mode=True,
        model_complexity=2,
        min_detection_confidence=MIN_DETECTION_CONFIDENCE,
    )

    valid_examples: list[ValidExample] = []
    summary: dict[str, Any] = {
        "bySplit": {split: {"total": 0, "valid": 0, "invalid": 0} for split in SPLITS},
        "invalidReasonsBySplit": {split: defaultdict(int) for split in SPLITS},
        "byClassAndSplit": defaultdict(lambda: {split: {"total": 0, "valid": 0} for split in SPLITS}),
    }

    for sample in samples:
        split = sample.split
        summary["bySplit"][split]["total"] += 1
        summary["byClassAndSplit"][sample.class_name][split]["total"] += 1

        image_path = dataset_dir / sample.relative_path
        bgr = cv2.imread(str(image_path))
        if bgr is None:
            summary["bySplit"][split]["invalid"] += 1
            summary["invalidReasonsBySplit"][split]["unreadableImage"] += 1
            continue

        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        result = pose.process(rgb)

        if result.pose_landmarks is None:
            summary["bySplit"][split]["invalid"] += 1
            summary["invalidReasonsBySplit"][split]["poseNotDetected"] += 1
            continue

        vector = normalize_landmarks(result.pose_landmarks.landmark)
        if vector is None:
            summary["bySplit"][split]["invalid"] += 1
            summary["invalidReasonsBySplit"][split]["lowConfidenceOrDegenerate"] += 1
            continue

        summary["bySplit"][split]["valid"] += 1
        summary["byClassAndSplit"][sample.class_name][split]["valid"] += 1
        valid_examples.append(
            ValidExample(
                class_name=sample.class_name,
                split=split,
                relative_path=sample.relative_path,
                vector=vector,
            )
        )

    pose.close()

    # Convert defaultdict objects to regular dicts for JSON serialization.
    summary["invalidReasonsBySplit"] = {
        split: dict(reason_counts)
        for split, reason_counts in summary["invalidReasonsBySplit"].items()
    }
    summary["byClassAndSplit"] = {
        class_name: dict(split_data)
        for class_name, split_data in summary["byClassAndSplit"].items()
    }
    return valid_examples, summary


def build_templates_from_train(valid_examples: list[ValidExample]) -> dict[str, dict[str, list[float]]]:
    vectors_by_class: dict[str, list[list[float]]] = defaultdict(list)
    for example in valid_examples:
        if example.split == "train":
            vectors_by_class[example.class_name].append(example.vector)

    templates: dict[str, dict[str, list[float]]] = {}
    for class_name, vectors in sorted(vectors_by_class.items()):
        matrix = np.array(vectors)
        mean_vector = matrix.mean(axis=0)
        mean_list = [round(float(value), 6) for value in mean_vector]
        templates[class_name] = {"meanVector": mean_list}
    return templates


def euclidean_distance(vec_a: list[float], vec_b: list[float]) -> float:
    array_a = np.array(vec_a, dtype=float)
    array_b = np.array(vec_b, dtype=float)
    return float(np.linalg.norm(array_a - array_b))


def predict_class(vector: list[float], templates: dict[str, dict[str, list[float]]]) -> str:
    best_class = ""
    best_distance = float("inf")
    for class_name, payload in templates.items():
        distance = euclidean_distance(vector, payload["meanVector"])
        if distance < best_distance:
            best_distance = distance
            best_class = class_name
    return best_class


def safe_divide(numerator: float, denominator: float) -> float:
    if denominator == 0:
        return 0.0
    return numerator / denominator


def evaluate_split(
    split_name: str,
    valid_examples: list[ValidExample],
    templates: dict[str, dict[str, list[float]]],
) -> dict[str, Any]:
    labels = sorted(templates.keys())
    label_to_index = {label: idx for idx, label in enumerate(labels)}

    split_examples = [example for example in valid_examples if example.split == split_name]

    skipped_unknown_class = 0
    y_true: list[str] = []
    y_pred: list[str] = []

    for example in split_examples:
        if example.class_name not in label_to_index:
            skipped_unknown_class += 1
            continue
        prediction = predict_class(example.vector, templates)
        y_true.append(example.class_name)
        y_pred.append(prediction)

    matrix = np.zeros((len(labels), len(labels)), dtype=int)
    for true_label, pred_label in zip(y_true, y_pred):
        matrix[label_to_index[true_label], label_to_index[pred_label]] += 1

    total = int(matrix.sum())
    correct = int(np.trace(matrix))
    accuracy = safe_divide(correct, total)

    per_class: dict[str, dict[str, Any]] = {}
    f1_values: list[float] = []

    for label in labels:
        idx = label_to_index[label]
        tp = int(matrix[idx, idx])
        fp = int(matrix[:, idx].sum() - tp)
        fn = int(matrix[idx, :].sum() - tp)
        support = int(matrix[idx, :].sum())
        precision = safe_divide(tp, tp + fp)
        recall = safe_divide(tp, tp + fn)
        f1 = safe_divide(2 * precision * recall, precision + recall) if (precision + recall) > 0 else 0.0
        if support > 0:
            f1_values.append(f1)
        per_class[label] = {
            "precision": round(precision, 6),
            "recall": round(recall, 6),
            "f1": round(f1, 6),
            "support": support,
        }

    macro_f1 = float(np.mean(f1_values)) if f1_values else 0.0

    confusion_matrix = {
        "labels": labels,
        "rows": {
            true_label: {
                pred_label: int(matrix[label_to_index[true_label], label_to_index[pred_label]])
                for pred_label in labels
            }
            for true_label in labels
        },
    }

    return {
        "split": split_name,
        "numValidExamples": len(split_examples),
        "numEvaluatedExamples": total,
        "numSkippedUnknownClass": skipped_unknown_class,
        "accuracy": round(accuracy, 6),
        "macroF1": round(macro_f1, 6),
        "perClass": per_class,
        "confusionMatrix": confusion_matrix,
    }


def run_quality_gate(
    validation_result: dict[str, Any],
    test_result: dict[str, Any],
    min_val_macro_f1: float,
    min_test_accuracy: float,
    min_test_macro_f1: float,
    disable_gate: bool,
) -> dict[str, Any]:
    checks: list[dict[str, Any]] = []

    checks.append(
        {
            "name": "validation_macro_f1",
            "value": validation_result.get("macroF1", 0.0),
            "minimum": min_val_macro_f1,
        }
    )
    checks.append(
        {
            "name": "test_accuracy",
            "value": test_result.get("accuracy", 0.0),
            "minimum": min_test_accuracy,
        }
    )
    checks.append(
        {
            "name": "test_macro_f1",
            "value": test_result.get("macroF1", 0.0),
            "minimum": min_test_macro_f1,
        }
    )

    failed_checks: list[str] = []
    for check in checks:
        if float(check["value"]) < float(check["minimum"]):
            failed_checks.append(
                f"{check['name']}={check['value']:.4f} "
                f"(min {check['minimum']:.4f})"
            )

    passed = len(failed_checks) == 0
    return {
        "enabled": not disable_gate,
        "passed": passed,
        "checks": checks,
        "failedChecks": failed_checks,
    }


def print_split_summary(samples: list[Sample]) -> None:
    counts = defaultdict(lambda: defaultdict(int))
    for sample in samples:
        counts[sample.class_name][sample.split] += 1

    print("\nSplit Assignment (total images)")
    print("-" * 72)
    print(f"{'Class':<18} {'Train':>8} {'Validation':>12} {'Test':>8} {'Total':>10}")
    print("-" * 72)
    for class_name in sorted(counts.keys()):
        train_count = counts[class_name]["train"]
        val_count = counts[class_name]["validation"]
        test_count = counts[class_name]["test"]
        total = train_count + val_count + test_count
        print(f"{class_name:<18} {train_count:>8} {val_count:>12} {test_count:>8} {total:>10}")


def print_metrics(title: str, metrics: dict[str, Any]) -> None:
    print(f"\n{title}")
    print("-" * 72)
    print(
        f"Examples: {metrics['numEvaluatedExamples']} evaluated "
        f"({metrics['numValidExamples']} valid extracted)"
    )
    print(f"Accuracy: {metrics['accuracy']:.4f}")
    print(f"Macro F1: {metrics['macroF1']:.4f}")


def main() -> None:
    args = parse_args()

    try:
        validate_split_ratios(args.train_ratio, args.validation_ratio, args.test_ratio)
    except ValueError as error:
        print(f"[ERROR] {error}")
        sys.exit(1)

    print("=" * 72)
    print("ZenPose Template Training + Evaluation Pipeline")
    print("=" * 72)

    try:
        class_to_images = get_dataset_index(args.dataset_dir)
    except (FileNotFoundError, RuntimeError) as error:
        print(f"[ERROR] {error}")
        sys.exit(1)

    samples = build_split_manifest(
        class_to_images=class_to_images,
        dataset_dir=args.dataset_dir,
        train_ratio=args.train_ratio,
        validation_ratio=args.validation_ratio,
        test_ratio=args.test_ratio,
        seed=args.seed,
    )
    print_split_summary(samples)
    save_split_manifest(
        path=args.split_manifest,
        samples=samples,
        seed=args.seed,
        train_ratio=args.train_ratio,
        validation_ratio=args.validation_ratio,
        test_ratio=args.test_ratio,
    )
    print(f"\nSaved split manifest: {args.split_manifest}")

    print("\nExtracting pose vectors with MediaPipe...")
    valid_examples, extraction_summary = extract_valid_examples(args.dataset_dir, samples)

    for split in SPLITS:
        split_summary = extraction_summary["bySplit"][split]
        print(
            f"  {split:<10} total={split_summary['total']:<5} "
            f"valid={split_summary['valid']:<5} invalid={split_summary['invalid']:<5}"
        )

    templates = build_templates_from_train(valid_examples)
    if not templates:
        print("\n[ERROR] No templates generated. No valid training vectors found.")
        sys.exit(1)

    args.output_file.parent.mkdir(parents=True, exist_ok=True)
    with args.output_file.open("w", encoding="utf-8") as file:
        json.dump(templates, file, indent=2)
    print(f"\nSaved templates JSON: {args.output_file}")

    validation_result = evaluate_split("validation", valid_examples, templates)
    test_result = evaluate_split("test", valid_examples, templates)
    print_metrics("Validation Metrics", validation_result)
    print_metrics("Test Metrics", test_result)

    gate_result = run_quality_gate(
        validation_result=validation_result,
        test_result=test_result,
        min_val_macro_f1=args.min_val_macro_f1,
        min_test_accuracy=args.min_test_accuracy,
        min_test_macro_f1=args.min_test_macro_f1,
        disable_gate=args.disable_gate,
    )

    report = {
        "createdAtUtc": datetime.now(timezone.utc).isoformat(),
        "datasetDir": str(args.dataset_dir),
        "outputFile": str(args.output_file),
        "splitManifestFile": str(args.split_manifest),
        "ratios": {
            "train": args.train_ratio,
            "validation": args.validation_ratio,
            "test": args.test_ratio,
        },
        "seed": args.seed,
        "extractionSummary": extraction_summary,
        "numTemplates": len(templates),
        "evaluation": {
            "validation": validation_result,
            "test": test_result,
        },
        "gate": gate_result,
    }

    args.report_file.parent.mkdir(parents=True, exist_ok=True)
    with args.report_file.open("w", encoding="utf-8") as file:
        json.dump(report, file, indent=2)
    print(f"\nSaved evaluation report: {args.report_file}")

    print("\nQuality Gate")
    print("-" * 72)
    for check in gate_result["checks"]:
        status = "PASS" if check["value"] >= check["minimum"] else "FAIL"
        print(
            f"{status}  {check['name']}: "
            f"{check['value']:.4f} (min {check['minimum']:.4f})"
        )

    if gate_result["enabled"] and not gate_result["passed"]:
        print("\n[BLOCKED] Quality gate failed. Review report before adoption.")
        for failed in gate_result["failedChecks"]:
            print(f"  - {failed}")
        sys.exit(2)

    if gate_result["enabled"] and gate_result["passed"]:
        print("\n[READY] Quality gate passed. Safe to adopt these templates.")
    else:
        print("\n[INFO] Gate disabled. Check metrics manually before adoption.")


if __name__ == "__main__":
    main()
