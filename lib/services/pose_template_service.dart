import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../models/pose_template.dart';

/// Loads and caches [PoseTemplate] objects from the bundled JSON asset.
///
/// Architecture notes:
///   • Templates are loaded lazily on first access via [loadTemplates].
///   • Once loaded they are cached in-memory for the app lifetime.
///   • The JSON file (`assets/pose_templates.json`) is produced offline by
///     `generate_pose_templates.py` and bundled via `pubspec.yaml`.
///
/// Usage:
/// ```dart
/// final service = PoseTemplateService();
/// final templates = await service.loadTemplates();
/// ```
class PoseTemplateService {
  /// In-memory cache of parsed templates (null until first load).
  List<PoseTemplate>? _cache;

  /// Path to the JSON asset within the Flutter asset bundle.
  static const String _assetPath = 'assets/pose_templates.json';

  /// Load and parse all pose templates from the asset bundle.
  ///
  /// Returns cached results on subsequent calls.  Throws [FlutterError]
  /// if the asset cannot be found (usually means pubspec.yaml is missing
  /// an `assets:` entry).
  Future<List<PoseTemplate>> loadTemplates() async {
    // Return cached list if already loaded.
    if (_cache != null) return _cache!;

    // Read the raw JSON string from the asset bundle.
    final jsonString = await rootBundle.loadString(_assetPath);

    // Decode the top-level JSON array.
    final List<dynamic> jsonList = json.decode(jsonString) as List<dynamic>;

    // Map each JSON object to a PoseTemplate and cache the result.
    _cache = jsonList
        .map((item) => PoseTemplate.fromJson(item as Map<String, dynamic>))
        .toList();

    return _cache!;
  }

  /// Clear the in-memory cache (useful for hot-reload during development).
  void clearCache() => _cache = null;
}
