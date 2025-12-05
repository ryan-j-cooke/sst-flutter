import 'package:shared_preferences/shared_preferences.dart';
import 'package:stttest/utils/sherpa-onxx-sst.dart';

/// Tutor Service
///
/// Manages tutor-related settings and preferences in persistent local storage.
class TutorService {
  /// Storage key prefix for model priorities
  static const String _modelPriorityPrefix = 'tutor_model_priority_';

  /// Get the storage key for a language's model priority
  static String _getModelPriorityKey(String languageCode) {
    return '$_modelPriorityPrefix$languageCode';
  }

  /// Save the priority model for a specific language
  ///
  /// [languageCode] - The language code (e.g., 'en', 'el', 'th')
  /// [model] - The SherpaModelType to set as priority (optional, for enum models)
  /// [modelName] - The model name string (for custom models or as alternative)
  ///
  /// Returns true if saved successfully, false otherwise
  static Future<bool> saveModelPriority(
    String languageCode,
    SherpaModelType? model, {
    String? modelName,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getModelPriorityKey(languageCode);
      // Store the model name as string (e.g., 'sherpa-onnx-zipformer-en-2023-06-26')
      final nameToSave = modelName ?? model?.modelName;
      if (nameToSave == null) return false;
      await prefs.setString(key, nameToSave);
      return true;
    } catch (e) {
      print('[TutorService] Error saving model priority: $e');
      return false;
    }
  }

  /// Get the priority model name for a specific language
  ///
  /// [languageCode] - The language code (e.g., 'en', 'el', 'th')
  ///
  /// Returns the saved model name string, or null if not set
  static Future<String?> getModelPriorityName(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getModelPriorityKey(languageCode);
      return prefs.getString(key);
    } catch (e) {
      print('[TutorService] Error getting model priority: $e');
      return null;
    }
  }

  /// Get the priority model for a specific language (returns enum if found)
  ///
  /// [languageCode] - The language code (e.g., 'en', 'el', 'th')
  ///
  /// Returns the saved SherpaModelType, or null if not set or not an enum model
  static Future<SherpaModelType?> getModelPriority(String languageCode) async {
    try {
      final modelName = await getModelPriorityName(languageCode);
      if (modelName == null) return null;

      // Convert string back to SherpaModelType by matching modelName
      for (final model in SherpaModelType.values) {
        if (model.modelName == modelName) {
          return model;
        }
      }

      return null;
    } catch (e) {
      print('[TutorService] Error getting model priority: $e');
      return null;
    }
  }

  /// Clear the model priority for a specific language
  ///
  /// [languageCode] - The language code to clear
  ///
  /// Returns true if cleared successfully, false otherwise
  static Future<bool> clearModelPriority(String languageCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getModelPriorityKey(languageCode);
      await prefs.remove(key);
      return true;
    } catch (e) {
      print('[TutorService] Error clearing model priority: $e');
      return false;
    }
  }
}
