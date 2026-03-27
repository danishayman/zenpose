import '../models/pose_template.dart';

class PoseDemoAssetResolver {
  static const String demoAssetDirectory = 'assets/pose_gifs';

  static String gifPathForTemplate(PoseTemplate template) {
    return '$demoAssetDirectory/${template.templateKey}.gif';
  }
}
