import '../models/pose_template.dart';

class PoseDemoAssetResolver {
  static const String demoAssetDirectory = 'assets/pose_gifs';
  static const String thumbnailAssetDirectory = 'assets/thumbnail';

  static String gifPathForTemplate(PoseTemplate template) {
    return '$demoAssetDirectory/${template.templateKey}.gif';
  }

  static String thumbnailPathForTemplate(PoseTemplate template) {
    return '$thumbnailAssetDirectory/${template.templateKey}.jpg';
  }
}
