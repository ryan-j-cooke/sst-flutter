import 'package:stttest/utils/sherpa-onxx-sst.dart';

/// Model accuracy levels
enum ModelAccuracy { lowest, low, moderate, high, highest }

/// Model speed levels
enum ModelSpeed { fastest, fast, moderate, slow, slowest }

/// Model variant information
///
/// Can represent both enum-based models (SherpaModelType) and string-based model names
/// for models that haven't been added to the enum yet.
class SherpaModelVariant {
  final SherpaModelType? model; // Null if using custom model name
  final String? customModelName; // Used for models not in enum
  final ModelAccuracy accuracy;
  final ModelSpeed speed;
  final String fileSize;
  final String
  modelName; // Full model name (e.g., 'sherpa-onnx-zipformer-en-2023-06-26')
  final String displayName;
  final bool isCurrent; // Whether this is the currently used model

  const SherpaModelVariant({
    this.model,
    this.customModelName,
    required this.accuracy,
    required this.speed,
    required this.fileSize,
    required this.modelName,
    required this.displayName,
    required this.isCurrent,
  }) : assert(
         model != null || customModelName != null,
         'Either model or customModelName must be provided',
       );

  /// Get the actual model name to use for downloads/initialization
  String get actualModelName =>
      model?.modelName ?? customModelName ?? modelName;
}

/// Dictionary mapping language codes to available Sherpa-ONNX models
///
/// Models are organized by language code and sorted by accuracy (lowest to highest)
/// within each language group.
class SherpaModelDictionary {
  /// Get all available models for a language code
  static List<SherpaModelVariant> getModelsForLanguage(String languageCode) {
    final normalizedCode = _normalizeLanguageCode(languageCode);
    return _modelDictionary[normalizedCode] ?? [];
  }

  /// Get the default/recommended model for a language
  static SherpaModelVariant? getDefaultModelForLanguage(String languageCode) {
    final models = getModelsForLanguage(languageCode);
    if (models.isEmpty) return null;

    // Return the first model (usually the balanced one) or the current one
    return models.firstWhere((m) => m.isCurrent, orElse: () => models.first);
  }

  /// Normalize language code (e.g., 'zh-CN' -> 'zh', 'es-ES' -> 'es')
  static String _normalizeLanguageCode(String code) {
    if (code.contains('-')) {
      return code.split('-').first;
    }
    return code;
  }

  /// Get all language codes that have models available
  static List<String> getAvailableLanguageCodes() {
    return _modelDictionary.keys.toList();
  }

  /// Complete model dictionary organized by language code
  static final Map<String, List<SherpaModelVariant>> _modelDictionary = {
    // English (en) - Multiple variants available
    'en': [
      // Smallest/Fastest - Whisper Tiny
      SherpaModelVariant(
        model: SherpaModelType.whisperTiny,
        accuracy: ModelAccuracy.lowest,
        speed: ModelSpeed.fastest,
        fileSize: '~111 MB',
        modelName: 'sherpa-onnx-whisper-tiny',
        displayName: 'Whisper Tiny',
        isCurrent: false,
      ),
      // Small - Zipformer Small
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-zipformer-small-en-2023-06-26',
        accuracy: ModelAccuracy.low,
        speed: ModelSpeed.fastest,
        fileSize: '~107 MB',
        modelName: 'sherpa-onnx-zipformer-small-en-2023-06-26',
        displayName: 'Zipformer Small EN',
        isCurrent: false,
      ),
      // Medium - Whisper Base
      SherpaModelVariant(
        model: SherpaModelType.whisperBase,
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~198 MB',
        modelName: 'sherpa-onnx-whisper-base',
        displayName: 'Whisper Base',
        isCurrent: false,
      ),
      // Balanced - Zipformer EN (standard)
      SherpaModelVariant(
        model: SherpaModelType.zipformerEn,
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~293 MB',
        modelName: 'sherpa-onnx-zipformer-en-2023-06-26',
        displayName: 'Zipformer EN',
        isCurrent: false,
      ),
      // Large - Zipformer Large
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-zipformer-large-en-2023-06-26',
        accuracy: ModelAccuracy.high,
        speed: ModelSpeed.moderate,
        fileSize: '~657 MB',
        modelName: 'sherpa-onnx-zipformer-large-en-2023-06-26',
        displayName: 'Zipformer Large EN',
        isCurrent: false,
      ),
      // High Accuracy - Whisper Small
      SherpaModelVariant(
        model: SherpaModelType.whisperSmall,
        accuracy: ModelAccuracy.high,
        speed: ModelSpeed.slow,
        fileSize: '~610 MB',
        modelName: 'sherpa-onnx-whisper-small',
        displayName: 'Whisper Small',
        isCurrent: false,
      ),
      // Streaming models
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-streaming-zipformer-en-20M-2023-02-17',
        accuracy: ModelAccuracy.low,
        speed: ModelSpeed.fastest,
        fileSize: '~122 MB',
        modelName: 'sherpa-onnx-streaming-zipformer-en-20M-2023-02-17',
        displayName: 'Streaming Zipformer EN 20M',
        isCurrent: false,
      ),
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-streaming-zipformer-en-2023-06-26',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~296 MB',
        modelName: 'sherpa-onnx-streaming-zipformer-en-2023-06-26',
        displayName: 'Streaming Zipformer EN',
        isCurrent: false,
      ),
      // Paraformer models
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-paraformer-en-2024-03-09',
        accuracy: ModelAccuracy.high,
        speed: ModelSpeed.moderate,
        fileSize: '~974 MB',
        modelName: 'sherpa-onnx-paraformer-en-2024-03-09',
        displayName: 'Paraformer EN',
        isCurrent: false,
      ),
      // LSTM models
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-lstm-en-2023-02-17',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.moderate,
        fileSize: '~366 MB',
        modelName: 'sherpa-onnx-lstm-en-2023-02-17',
        displayName: 'LSTM EN',
        isCurrent: false,
      ),
      // Conformer models
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-conformer-en-2023-03-18',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.moderate,
        fileSize: '~406 MB',
        modelName: 'sherpa-onnx-conformer-en-2023-03-18',
        displayName: 'Conformer EN',
        isCurrent: false,
      ),
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-streaming-conformer-en-2023-05-09',
        accuracy: ModelAccuracy.high,
        speed: ModelSpeed.slow,
        fileSize: '~627 MB',
        modelName: 'sherpa-onnx-streaming-conformer-en-2023-05-09',
        displayName: 'Streaming Conformer EN',
        isCurrent: false,
      ),
      // Wenet models
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-en-wenet-librispeech',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.moderate,
        fileSize: '~341 MB',
        modelName: 'sherpa-onnx-en-wenet-librispeech',
        displayName: 'Wenet LibriSpeech EN',
        isCurrent: false,
      ),
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-en-wenet-gigaspeech',
        accuracy: ModelAccuracy.high,
        speed: ModelSpeed.slow,
        fileSize: '~890 MB',
        modelName: 'sherpa-onnx-en-wenet-gigaspeech',
        displayName: 'Wenet GigaSpeech EN',
        isCurrent: false,
      ),
      // NeMo models
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-nemo-ctc-en-citrinet-512',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~157 MB',
        modelName: 'sherpa-onnx-nemo-ctc-en-citrinet-512',
        displayName: 'NeMo Citrinet EN',
        isCurrent: false,
      ),
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-nemo-ctc-en-conformer-small',
        accuracy: ModelAccuracy.low,
        speed: ModelSpeed.fastest,
        fileSize: '~72.9 MB',
        modelName: 'sherpa-onnx-nemo-ctc-en-conformer-small',
        displayName: 'NeMo Conformer Small EN',
        isCurrent: false,
      ),
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-nemo-ctc-en-conformer-medium',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~158 MB',
        modelName: 'sherpa-onnx-nemo-ctc-en-conformer-medium',
        displayName: 'NeMo Conformer Medium EN',
        isCurrent: false,
      ),
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-nemo-ctc-en-conformer-large',
        accuracy: ModelAccuracy.high,
        speed: ModelSpeed.moderate,
        fileSize: '~582 MB',
        modelName: 'sherpa-onnx-nemo-ctc-en-conformer-large',
        displayName: 'NeMo Conformer Large EN',
        isCurrent: false,
      ),
    ],

    // Thai (th)
    'th': [
      SherpaModelVariant(
        model: SherpaModelType.zipformerTh,
        accuracy: ModelAccuracy.high,
        speed: ModelSpeed.moderate,
        fileSize: '~663 MB',
        modelName: 'sherpa-onnx-zipformer-thai-2024-06-20',
        displayName: 'Zipformer TH',
        isCurrent: true, // This is the current model in main.dart (line 223)
      ),
    ],

    // Chinese (zh) - Multiple variants available
    'zh': [
      // Smallest/Fastest - Paraformer Small
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-paraformer-zh-small-2024-03-09',
        accuracy: ModelAccuracy.lowest,
        speed: ModelSpeed.fastest,
        fileSize: '~74.3 MB',
        modelName: 'sherpa-onnx-paraformer-zh-small-2024-03-09',
        displayName: 'Paraformer ZH Small',
        isCurrent: false,
      ),
      // Current model - Zipformer ZH (from main.dart lines 28-30)
      SherpaModelVariant(
        model: SherpaModelType.zipformerZh,
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~298 MB',
        modelName: 'sherpa-onnx-zipformer-zh-en-2023-11-22',
        displayName: 'Zipformer ZH',
        isCurrent: true, // This is the current model in main.dart
      ),
      // Medium - Paraformer 2023
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-paraformer-zh-2023-03-28',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.moderate,
        fileSize: '~988 MB',
        modelName: 'sherpa-onnx-paraformer-zh-2023-03-28',
        displayName: 'Paraformer ZH (2023)',
        isCurrent: false,
      ),
      // Large/High Accuracy - Paraformer 2024
      SherpaModelVariant(
        model: SherpaModelType.paraformerZh,
        accuracy: ModelAccuracy.high,
        speed: ModelSpeed.moderate,
        fileSize: '~950 MB',
        modelName: 'sherpa-onnx-paraformer-zh-2024-03-09',
        displayName: 'Paraformer ZH',
        isCurrent: false,
      ),
      // Very Large/Highest - Paraformer 2025
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-paraformer-zh-2025-10-07',
        accuracy: ModelAccuracy.highest,
        speed: ModelSpeed.slow,
        fileSize: '~784 MB',
        modelName: 'sherpa-onnx-paraformer-zh-2025-10-07',
        displayName: 'Paraformer ZH (2025)',
        isCurrent: false,
      ),
      // Streaming models
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23',
        accuracy: ModelAccuracy.low,
        speed: ModelSpeed.fastest,
        fileSize: '~70.6 MB',
        modelName: 'sherpa-onnx-streaming-zipformer-zh-14M-2023-02-23',
        displayName: 'Streaming Zipformer ZH 14M',
        isCurrent: false,
      ),
      // Bilingual models (zh-en)
      SherpaModelVariant(
        customModelName:
            'sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~488 MB',
        modelName: 'sherpa-onnx-streaming-zipformer-bilingual-zh-en-2023-02-20',
        displayName: 'Streaming Zipformer ZH-EN',
        isCurrent: false,
      ),
      SherpaModelVariant(
        customModelName:
            'sherpa-onnx-streaming-zipformer-small-bilingual-zh-en-2023-02-16',
        accuracy: ModelAccuracy.low,
        speed: ModelSpeed.fast,
        fileSize: '~437 MB',
        modelName:
            'sherpa-onnx-streaming-zipformer-small-bilingual-zh-en-2023-02-16',
        displayName: 'Streaming Zipformer Small ZH-EN',
        isCurrent: false,
      ),
      // Trilingual models
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-paraformer-trilingual-zh-cantonese-en',
        accuracy: ModelAccuracy.high,
        speed: ModelSpeed.slow,
        fileSize: '~1010 MB',
        modelName: 'sherpa-onnx-paraformer-trilingual-zh-cantonese-en',
        displayName: 'Paraformer Trilingual (ZH-Cantonese-EN)',
        isCurrent: false,
      ),
      // Wenet models
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-zh-wenet-aishell',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.moderate,
        fileSize: '~339 MB',
        modelName: 'sherpa-onnx-zh-wenet-aishell',
        displayName: 'Wenet AIShell ZH',
        isCurrent: false,
      ),
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-zh-wenet-wenetspeech',
        accuracy: ModelAccuracy.high,
        speed: ModelSpeed.slow,
        fileSize: '~848 MB',
        modelName: 'sherpa-onnx-zh-wenet-wenetspeech',
        displayName: 'Wenet WenetSpeech ZH',
        isCurrent: false,
      ),
    ],

    // Russian (ru) - Multiple variants available
    'ru': [
      // Standard - Zipformer RU
      SherpaModelVariant(
        model: SherpaModelType.zipformerRu,
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~284 MB',
        modelName: 'sherpa-onnx-zipformer-ru-2024-09-18',
        displayName: 'Zipformer RU',
        isCurrent: false,
      ),
      // Small variant
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-small-zipformer-ru-2024-09-18',
        accuracy: ModelAccuracy.low,
        speed: ModelSpeed.fastest,
        fileSize: '~105 MB',
        modelName: 'sherpa-onnx-small-zipformer-ru-2024-09-18',
        displayName: 'Small Zipformer RU',
        isCurrent: false,
      ),
      // Updated 2025 version
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-zipformer-ru-2025-04-20',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~237 MB',
        modelName: 'sherpa-onnx-zipformer-ru-2025-04-20',
        displayName: 'Zipformer RU (2025)',
        isCurrent: false,
      ),
      // Streaming models
      SherpaModelVariant(
        customModelName:
            'sherpa-onnx-streaming-zipformer-small-ru-vosk-2025-08-16',
        accuracy: ModelAccuracy.low,
        speed: ModelSpeed.fastest,
        fileSize: '~23 MB',
        modelName: 'sherpa-onnx-streaming-zipformer-small-ru-vosk-2025-08-16',
        displayName: 'Streaming Zipformer Small RU (Vosk)',
        isCurrent: false,
      ),
      SherpaModelVariant(
        customModelName:
            'sherpa-onnx-streaming-zipformer-small-ru-vosk-int8-2025-08-16',
        accuracy: ModelAccuracy.lowest,
        speed: ModelSpeed.fastest,
        fileSize: '~85.5 MB',
        modelName: 'sherpa-onnx-streaming-zipformer-small-ru-vosk-2025-08-16',
        displayName: 'Streaming Zipformer Small RU (Vosk INT8)',
        isCurrent: false,
      ),
      // NeMo models
      SherpaModelVariant(
        customModelName:
            'sherpa-onnx-nemo-transducer-giga-am-russian-2024-10-24',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.moderate,
        fileSize: '~196 MB',
        modelName: 'sherpa-onnx-nemo-transducer-giga-am-russian-2024-10-24',
        displayName: 'NeMo Transducer Russian',
        isCurrent: false,
      ),
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-nemo-ctc-giga-am-russian-2024-10-24',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.moderate,
        fileSize: '~191 MB',
        modelName: 'sherpa-onnx-nemo-ctc-giga-am-russian-2024-10-24',
        displayName: 'NeMo CTC Russian',
        isCurrent: false,
      ),
    ],

    // Korean (ko) - Multiple variants available
    'ko': [
      // Standard - Zipformer KO
      SherpaModelVariant(
        model: SherpaModelType.zipformerKo,
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~314 MB',
        modelName: 'sherpa-onnx-zipformer-korean-2024-06-24',
        displayName: 'Zipformer KO',
        isCurrent: false,
      ),
      // Streaming variant
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-streaming-zipformer-korean-2024-06-16',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~399 MB',
        modelName: 'sherpa-onnx-streaming-zipformer-korean-2024-06-16',
        displayName: 'Streaming Zipformer KO',
        isCurrent: false,
      ),
    ],

    // Japanese (ja) - Multiple variants available
    'ja': [
      // Zipformer Japanese
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-zipformer-ja-reazonspeech-2024-08-01',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~680 MB',
        modelName: 'sherpa-onnx-zipformer-ja-reazonspeech-2024-08-01',
        displayName: 'Zipformer JA (ReazonSpeech)',
        isCurrent: false,
      ),
      // Bilingual Japanese-English
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-zipformer-ja-en-reazonspeech-2025-01-17',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~418 MB',
        modelName: 'sherpa-onnx-zipformer-ja-en-reazonspeech-2025-01-17',
        displayName: 'Zipformer JA-EN',
        isCurrent: false,
      ),
    ],

    // French (fr) - Multiple variants available
    'fr': [
      // Streaming Zipformer French
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-streaming-zipformer-fr-2023-04-14',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~380 MB',
        modelName: 'sherpa-onnx-streaming-zipformer-fr-2023-04-14',
        displayName: 'Streaming Zipformer FR',
        isCurrent: false,
      ),
      // Kroko variant
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-streaming-zipformer-fr-kroko-2025-08-06',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~54.6 MB',
        modelName: 'sherpa-onnx-streaming-zipformer-fr-kroko-2025-08-06',
        displayName: 'Streaming Zipformer FR (Kroko)',
        isCurrent: false,
      ),
    ],

    // Spanish (es) - Multiple variants available
    'es': [
      // Kroko variant
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-streaming-zipformer-es-kroko-2025-08-06',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~119 MB',
        modelName: 'sherpa-onnx-streaming-zipformer-es-kroko-2025-08-06',
        displayName: 'Streaming Zipformer ES (Kroko)',
        isCurrent: false,
      ),
      // NeMo models
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-nemo-fast-conformer-ctc-es-1424',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.moderate,
        fileSize: '~411 MB',
        modelName: 'sherpa-onnx-nemo-fast-conformer-ctc-es-1424',
        displayName: 'NeMo Fast Conformer ES',
        isCurrent: false,
      ),
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-nemo-fast-conformer-transducer-es-1424',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.moderate,
        fileSize: '~428 MB',
        modelName: 'sherpa-onnx-nemo-fast-conformer-transducer-es-1424',
        displayName: 'NeMo Fast Conformer Transducer ES',
        isCurrent: false,
      ),
    ],

    // German (de) - Multiple variants available
    'de': [
      // Kroko variant
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-streaming-zipformer-de-kroko-2025-08-06',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~54.9 MB',
        modelName: 'sherpa-onnx-streaming-zipformer-de-kroko-2025-08-06',
        displayName: 'Streaming Zipformer DE (Kroko)',
        isCurrent: false,
      ),
      // NeMo models
      SherpaModelVariant(
        customModelName:
            'sherpa-onnx-nemo-stt_de_fastconformer_hybrid_large_pc',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.moderate,
        fileSize: '~411 MB',
        modelName: 'sherpa-onnx-nemo-stt_de_fastconformer_hybrid_large_pc',
        displayName: 'NeMo Fast Conformer DE',
        isCurrent: false,
      ),
      SherpaModelVariant(
        customModelName:
            'sherpa-onnx-nemo-transducer-stt_de_fastconformer_hybrid_large_pc',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.moderate,
        fileSize: '~428 MB',
        modelName:
            'sherpa-onnx-nemo-transducer-stt_de_fastconformer_hybrid_large_pc',
        displayName: 'NeMo Transducer DE',
        isCurrent: false,
      ),
    ],

    // Vietnamese (vi) - Multiple variants available
    'vi': [
      // Standard Zipformer Vietnamese
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-zipformer-vi-2025-04-20',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~244 MB',
        modelName: 'sherpa-onnx-zipformer-vi-2025-04-20',
        displayName: 'Zipformer VI',
        isCurrent: false,
      ),
      // INT8 variant
      SherpaModelVariant(
        customModelName: 'sherpa-onnx-zipformer-vi-int8-2025-04-20',
        accuracy: ModelAccuracy.low,
        speed: ModelSpeed.fastest,
        fileSize: '~57.4 MB',
        modelName: 'sherpa-onnx-zipformer-vi-int8-2025-04-20',
        displayName: 'Zipformer VI (INT8)',
        isCurrent: false,
      ),
    ],

    // Arabic (ar) - Models available in multilingual models
    'ar': [
      // Available through multilingual streaming models
      SherpaModelVariant(
        customModelName:
            'sherpa-onnx-streaming-zipformer-ar_en_id_ja_ru_th_vi_zh-2025-02-10',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~247 MB',
        modelName:
            'sherpa-onnx-streaming-zipformer-ar_en_id_ja_ru_th_vi_zh-2025-02-10',
        displayName:
            'Streaming Zipformer Multilingual (AR-EN-ID-JA-RU-TH-VI-ZH)',
        isCurrent: false,
      ),
    ],

    // Portuguese (pt) - Multiple variants available
    'pt': [
      // NeMo Portuguese models
      SherpaModelVariant(
        customModelName:
            'sherpa-onnx-nemo-stt_pt_fastconformer_hybrid_large_pc',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.moderate,
        fileSize: '~413 MB',
        modelName: 'sherpa-onnx-nemo-stt_pt_fastconformer_hybrid_large_pc',
        displayName: 'NeMo Fast Conformer PT',
        isCurrent: false,
      ),
      SherpaModelVariant(
        customModelName:
            'sherpa-onnx-nemo-transducer-stt_pt_fastconformer_hybrid_large_pc',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.moderate,
        fileSize: '~428 MB',
        modelName:
            'sherpa-onnx-nemo-transducer-stt_pt_fastconformer_hybrid_large_pc',
        displayName: 'NeMo Transducer PT',
        isCurrent: false,
      ),
    ],

    // Indonesian (id) - Available in multilingual models
    'id': [
      // Available through multilingual streaming models
      SherpaModelVariant(
        customModelName:
            'sherpa-onnx-streaming-zipformer-ar_en_id_ja_ru_th_vi_zh-2025-02-10',
        accuracy: ModelAccuracy.moderate,
        speed: ModelSpeed.fast,
        fileSize: '~247 MB',
        modelName:
            'sherpa-onnx-streaming-zipformer-ar_en_id_ja_ru_th_vi_zh-2025-02-10',
        displayName:
            'Streaming Zipformer Multilingual (AR-EN-ID-JA-RU-TH-VI-ZH)',
        isCurrent: false,
      ),
    ],

    // // Hebrew (he)
    // 'he': [
    //   // Note: No specific Hebrew model found in the list
    // ],

    // // Italian (it) - Models available in multilingual models
    // 'it': [
    //   // Available through multilingual models (e.g., be-de-en-es-fr-hr-it-pl-ru-uk-20k)
    //   // No dedicated Italian-only model found
    // ],

    // // Hindi (hi)
    // 'hi': [
    //   // Note: No specific Hindi model found
    // ],

    // // Bengali (bn)
    // 'bn': [
    //   // Note: No specific Bengali model found
    // ],

    // // Malay (ms)
    // 'ms': [
    //   // Note: No specific Malay model found
    // ],

    // // Turkish (tr)
    // 'tr': [
    //   // Note: Models available but not in current enum
    // ],

    // // Polish (pl)
    // 'pl': [
    //   // Note: Models available but not in current enum
    // ],

    // // Dutch (nl)
    // 'nl': [
    //   // Note: Models available but not in current enum
    // ],

    // // Swedish (sv)
    // 'sv': [
    //   // Note: No specific Swedish model found
    // ],

    // // Norwegian (no)
    // 'no': [
    //   // Note: No specific Norwegian model found
    // ],

    // // Finnish (fi)
    // 'fi': [
    //   // Note: No specific Finnish model found
    // ],

    // // Danish (da)
    // 'da': [
    //   // Note: No specific Danish model found
    // ],

    // // Greek (el)
    // 'el': [
    //   // Note: No specific Greek model found
    // ],

    // // Romanian (ro)
    // 'ro': [
    //   // Note: No specific Romanian model found
    // ],

    // // Hungarian (hu)
    // 'hu': [
    //   // Note: No specific Hungarian model found
    // ],

    // // Czech (cs)
    // 'cs': [
    //   // Note: No specific Czech model found
    // ],

    // // Slovak (sk)
    // 'sk': [
    //   // Note: No specific Slovak model found
    // ],

    // // Bulgarian (bg)
    // 'bg': [
    //   // Note: No specific Bulgarian model found
    // ],

    // // Ukrainian (uk)
    // 'uk': [
    //   // Note: No specific Ukrainian model found
    // ],

    // // Croatian (hr)
    // 'hr': [
    //   // Note: No specific Croatian model found
    // ],

    // // Serbian (sr)
    // 'sr': [
    //   // Note: No specific Serbian model found
    // ],

    // // Slovenian (sl)
    // 'sl': [
    //   // Note: No specific Slovenian model found
    // ],

    // // Lithuanian (lt)
    // 'lt': [
    //   // Note: No specific Lithuanian model found
    // ],

    // // Latvian (lv)
    // 'lv': [
    //   // Note: No specific Latvian model found
    // ],

    // // Estonian (et)
    // 'et': [
    //   // Note: No specific Estonian model found
    // ],

    // // Persian (fa)
    // 'fa': [
    //   // Note: No specific Persian model found
    // ],

    // // Tamil (ta)
    // 'ta': [
    //   // Note: No specific Tamil model found
    // ],

    // // Telugu (te)
    // 'te': [
    //   // Note: No specific Telugu model found
    // ],

    // // Kannada (kn)
    // 'kn': [
    //   // Note: No specific Kannada model found
    // ],

    // // Malayalam (ml)
    // 'ml': [
    //   // Note: No specific Malayalam model found
    // ],

    // // Marathi (mr)
    // 'mr': [
    //   // Note: No specific Marathi model found
    // ],

    // // Urdu (ur)
    // 'ur': [
    //   // Note: No specific Urdu model found
    // ],

    // // Swahili (sw)
    // 'sw': [
    //   // Note: No specific Swahili model found
    // ],

    // // Filipino (tl)
    // 'tl': [
    //   // Note: No specific Filipino model found
    // ],

    // // Zulu (zu)
    // 'zu': [
    //   // Note: No specific Zulu model found
    // ],

    // // Xhosa (xh)
    // 'xh': [
    //   // Note: No specific Xhosa model found
    // ],

    // // Sesotho (st)
    // 'st': [
    //   // Note: No specific Sesotho model found
    // ],

    // // Somali (so)
    // 'so': [
    //   // Note: No specific Somali model found
    // ],

    // // Yoruba (yo)
    // 'yo': [
    //   // Note: No specific Yoruba model found
    // ],

    // // Amharic (am)
    // 'am': [
    //   // Note: No specific Amharic model found
    // ],
  };
}
