import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:stttest/apps/components/bts/sst/sherpa-onnx-btn.dart';
import 'package:stttest/apps/components/download-card/index.dart';
import 'package:stttest/consts/languages.dart';
import 'package:stttest/utils/sherpa-model-dictionary.dart';
import 'package:stttest/utils/sherpa-onxx-sst.dart';
import 'package:stttest/apps/services/tutor/tutor.service.dart';

void main() {
  // Initialize sherpa-onnx bindings before using any sherpa-onnx functionality
  initBindings();
  runApp(const MyApp());
}

// SherpaModelType is imported from sherpa-onxx-sst.dart

// Language data structure for UI
class Language {
  final String name;
  final String code;
  final String flag;
  final List<SherpaModelVariant>? models; // Available models for this language

  const Language(this.name, this.code, this.flag, [this.models]);

  // Get grouped languages directly from SherpaModelDictionary
  // This ensures all languages with models are shown, regardless of LanguageConstants
  static Map<String, List<Language>> getGroupedLanguages() {
    final grouped = <String, List<Language>>{};

    // Get all language codes from the model dictionary
    final languageCodes = SherpaModelDictionary.getAvailableLanguageCodes();

    for (final languageCode in languageCodes) {
      final models = SherpaModelDictionary.getModelsForLanguage(languageCode);

      // Skip if no models available
      if (models.isEmpty) continue;

      // Try to get language info from LanguageConstants
      // First try exact match, then try normalized variants
      String? name;
      String? flag;
      String displayCode = languageCode;

      // Try exact match first
      if (LanguageConstants.languages.containsKey(languageCode)) {
        final langInfo = LanguageConstants.languages[languageCode];
        if (langInfo != null) {
          name = langInfo['name'];
          flag = langInfo['flag'];
          displayCode = languageCode;
        }
      }

      // If not found, try to find a variant (e.g., 'zh-CN' for 'zh')
      if (name == null) {
        final matchingEntry = LanguageConstants.languages.entries.firstWhere((
          e,
        ) {
          final normalized = e.key.contains('-')
              ? e.key.split('-').first
              : e.key;
          return normalized == languageCode;
        }, orElse: () => MapEntry('', <String, String>{}));

        if (matchingEntry.key.isNotEmpty) {
          final langInfo = matchingEntry.value;
          if (langInfo.isNotEmpty) {
            name = langInfo['name'];
            flag = langInfo['flag'];
            displayCode = matchingEntry.key;
          }
        }
      }

      // Fallback: generate name from code if still not found
      if (name == null) {
        name = _getLanguageNameFromCode(languageCode);
        flag = '🌐'; // Default flag
      }

      // Group by first letter of name
      final firstLetter = name.isNotEmpty ? name[0].toUpperCase() : '#';
      final groupKey = RegExp(r'[A-Z]').hasMatch(firstLetter)
          ? firstLetter
          : '#';

      grouped.putIfAbsent(groupKey, () => []);
      grouped[groupKey]!.add(Language(name, displayCode, flag ?? '🌐', models));
    }

    // Sort each group
    for (final group in grouped.values) {
      group.sort((a, b) => a.name.compareTo(b.name));
    }

    return grouped;
  }

  // Helper to generate language name from code if not in LanguageConstants
  static String _getLanguageNameFromCode(String code) {
    // Map of common language codes to names
    const codeToName = {
      'en': 'English',
      'th': 'Thai',
      'zh': 'Chinese',
      'ru': 'Russian',
      'ko': 'Korean',
      'ja': 'Japanese',
      'fr': 'French',
      'es': 'Spanish',
      'de': 'German',
      'vi': 'Vietnamese',
      'ar': 'Arabic',
      'pt': 'Portuguese',
      'id': 'Indonesian',
    };

    return codeToName[code] ?? code.toUpperCase();
  }
}

// Model selection data structure
class LanguageModelSelection {
  final Language language;
  final SherpaModelType? model; // null means use default or custom model
  final String? customModelName; // For custom models not in enum

  const LanguageModelSelection(
    this.language, [
    this.model,
    this.customModelName,
  ]);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sherpa-ONNX STT - Multilingual',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const SpeechTestPage(),
    );
  }
}

class SpeechTestPage extends StatefulWidget {
  const SpeechTestPage({super.key});

  @override
  State<SpeechTestPage> createState() => _SpeechTestPageState();
}

class _SpeechTestPageState extends State<SpeechTestPage> {
  bool _isInitializing = false;
  String _transcription = 'Press the button to start recording';
  String _statusMessage = 'Initializing...';

  Language? selectedLang;
  SherpaModelType? selectedModel;
  String? selectedCustomModelName; // For custom models not in enum

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    print('[main.dart] _initializeApp: Starting initialization...');
    setState(() {
      _isInitializing = true;
      _statusMessage = 'Initializing app...';
    });

    // Get all available languages from model dictionary
    final groupedLangs = Language.getGroupedLanguages();
    final allLangs = groupedLangs.values.expand((list) => list).toList();

    if (allLangs.isEmpty) {
      print(
        '[main.dart] _initializeApp: ERROR - No languages with models found!',
      );
      setState(() {
        _isInitializing = false;
        _statusMessage = 'No languages available';
      });
      return;
    }

    // Language-agnostic: Use first available language as default
    // In the future, this could be saved preference or user selection
    final defaultLang = allLangs.first;
    selectedLang = defaultLang;
    print(
      '[main.dart] _initializeApp: Selected default language: ${defaultLang.name} (${defaultLang.code})',
    );

    // Get the default model for the selected language
    final langModels = defaultLang.models ?? [];
    print(
      '[main.dart] _initializeApp: Available models for ${defaultLang.name}: ${langModels.length}',
    );

    SherpaModelType? defaultModel;
    if (langModels.isNotEmpty) {
      // Get the current model (isCurrent: true) or first available model with enum value
      final modelVariant = langModels.firstWhere(
        (m) => m.isCurrent && m.model != null,
        orElse: () => langModels.firstWhere(
          (m) => m.model != null,
          orElse: () => langModels.first,
        ),
      );
      defaultModel = modelVariant.model;
      print(
        '[main.dart] _initializeApp: Selected model: ${defaultModel?.displayName ?? modelVariant.displayName} (${modelVariant.modelName})',
      );
    } else {
      print(
        '[main.dart] _initializeApp: WARNING - No models found for ${defaultLang.name}!',
      );
    }

    // Load model for selected language
    await _loadModelForLanguage(selectedLang!.code, defaultModel);
  }

  Future<void> _loadModelForLanguage(
    String languageCode,
    SherpaModelType? specificModel, {
    String? customModelName,
  }) async {
    print(
      '[main.dart] _loadModelForLanguage: languageCode=$languageCode, specificModel=${specificModel?.displayName}, customModelName=$customModelName',
    );

    // Normalize language code
    final normalizedCode = languageCode.contains('-')
        ? languageCode.split('-').first
        : languageCode;
    print('[main.dart] _loadModelForLanguage: normalizedCode=$normalizedCode');

    // Determine which model to use
    SherpaModelType? modelToUse = specificModel;
    String? modelNameToUse = customModelName;

    print(
      '[main.dart] _loadModelForLanguage: modelToUse (from specificModel)=${modelToUse?.displayName}',
    );

    if (modelToUse == null && modelNameToUse == null) {
      // Get saved model preference
      final savedModel = await TutorService.getModelPriority(normalizedCode);
      print(
        '[main.dart] _loadModelForLanguage: savedModel from preferences=${savedModel?.displayName}',
      );
      if (savedModel != null) {
        modelToUse = savedModel;
      }
    }

    if (modelToUse == null && modelNameToUse == null) {
      // Get default model from dictionary
      final defaultVariant = SherpaModelDictionary.getDefaultModelForLanguage(
        normalizedCode,
      );
      print(
        '[main.dart] _loadModelForLanguage: defaultVariant from dictionary=${defaultVariant?.displayName}',
      );
      if (defaultVariant != null) {
        if (defaultVariant.model != null) {
          modelToUse = defaultVariant.model;
        } else if (defaultVariant.customModelName != null) {
          modelNameToUse = defaultVariant.customModelName;
        }
      }
    }

    if (modelToUse == null && modelNameToUse == null) {
      print('[main.dart] _loadModelForLanguage: ERROR - No model found!');
      setState(() {
        _isInitializing = false;
        _statusMessage = 'No model available for this language';
      });
      return;
    }

    // Check if model exists locally
    print(
      '[main.dart] _loadModelForLanguage: Checking if model exists locally...',
    );
    final modelName = modelToUse?.modelName ?? modelNameToUse!;
    final exists = await SherpaOnnxSTTHelper.modelExistsByName(modelName);
    print('[main.dart] _loadModelForLanguage: Model exists=$exists');

    if (exists) {
      print(
        '[main.dart] _loadModelForLanguage: Model exists, setting selectedModel and initializing...',
      );
      setState(() {
        selectedModel =
            modelToUse; // May be null for custom models, but that's OK
      });
      await _initializeSherpa();
    } else {
      print(
        '[main.dart] _loadModelForLanguage: Model does not exist, showing download dialog...',
      );
      // Model doesn't exist, show download dialog
      await _showModelDownloadDialog(modelToUse, modelName: modelNameToUse);
    }
  }

  Future<void> _initializeSherpa() async {
    print(
      '[main.dart] _initializeSherpa: Starting, selectedModel=${selectedModel?.displayName}',
    );
    if (selectedModel == null) {
      print('[main.dart] _initializeSherpa: ERROR - selectedModel is null!');
      return;
    }

    setState(() {
      _isInitializing = true;
      _statusMessage = 'Initializing Sherpa-ONNX...';
    });

    try {
      // Verify model exists (initialization happens in button)
      print('[main.dart] _initializeSherpa: Verifying model exists...');
      final exists = await SherpaOnnxSTTHelper.modelExists(selectedModel!);
      print('[main.dart] _initializeSherpa: Model exists=$exists');
      if (!exists) {
        throw Exception('Model not found');
      }

      print(
        '[main.dart] _initializeSherpa: Model verified, setting ready state',
      );
      setState(() {
        _isInitializing = false;
        _statusMessage = 'Ready (${selectedModel!.displayName})';
      });
      print(
        '[main.dart] _initializeSherpa: Complete - Ready with ${selectedModel!.displayName}',
      );
    } catch (e) {
      print('[main.dart] _initializeSherpa: ERROR - $e');
      setState(() {
        _isInitializing = false;
        _statusMessage = 'Error initializing: $e';
      });
      print('Error initializing Sherpa-ONNX: $e');
    }
  }

  /// Show download modal for a specific language (shows all models)
  Future<void> _showModelDownloadDialogForLanguage(String languageCode) async {
    if (!mounted) {
      print(
        '[main.dart] _showModelDownloadDialogForLanguage: Not mounted, returning',
      );
      return;
    }

    print(
      '[main.dart] _showModelDownloadDialogForLanguage: Starting for languageCode=$languageCode',
    );

    // Normalize language code
    final normalizedCode = languageCode.contains('-')
        ? languageCode.split('-').first
        : languageCode;

    print(
      '[main.dart] _showModelDownloadDialogForLanguage: normalizedCode=$normalizedCode',
    );

    // Get all available models for this language (both enum and custom)
    final allModels = SherpaModelDictionary.getModelsForLanguage(
      normalizedCode,
    );

    print(
      '[main.dart] _showModelDownloadDialogForLanguage: Found ${allModels.length} models',
    );

    if (allModels.isEmpty) {
      print(
        '[main.dart] _showModelDownloadDialogForLanguage: No models found, showing error',
      );
      setState(() {
        _statusMessage = 'No models available for this language';
      });
      return;
    }

    print('[main.dart] _showModelDownloadDialogForLanguage: Showing dialog...');
    // Show dialog with all models (even if already downloaded)
    // Pass languageCode and let ModelDownloadCard fetch models itself
    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5), // Transparent overlay
      barrierDismissible: true, // Allow dismissing by tapping outside
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ModelDownloadCard(
          requiredModels: [], // Empty - will be populated from languageCode
          languageCode: normalizedCode, // Pass normalized code
          onAllModelsDownloaded: () {
            print(
              '[main.dart] _showModelDownloadDialogForLanguage: onAllModelsDownloaded called',
            );
            Navigator.of(context).pop(true);
          },
        ),
      ),
    );

    print(
      '[main.dart] _showModelDownloadDialogForLanguage: Dialog result=$result',
    );

    if (result == true && mounted && selectedLang != null) {
      // Model downloaded and saved (step-2 saves via TutorService)
      // Reload the saved model preference
      final savedModel = await TutorService.getModelPriority(normalizedCode);
      if (savedModel != null) {
        selectedModel = savedModel;
        selectedCustomModelName = null;
        await _initializeSherpa();
      } else {
        // Get first available enum model as fallback
        final allModelsForLang = SherpaModelDictionary.getModelsForLanguage(
          normalizedCode,
        );
        final enumModelsForLang = allModelsForLang
            .where((m) => m.model != null)
            .map((m) => m.model!)
            .toList();
        if (enumModelsForLang.isNotEmpty) {
          // Use first available model
          selectedModel = enumModelsForLang.first;
          selectedCustomModelName = null;
          await TutorService.saveModelPriority(
            normalizedCode,
            enumModelsForLang.first,
          );
          await _initializeSherpa();
        }
      }
    }
  }

  Future<void> _showModelDownloadDialog(
    SherpaModelType? model, {
    String? modelName,
  }) async {
    if (!mounted || selectedLang == null) return;

    // Get all available models for this language
    final normalizedCode = selectedLang!.code.contains('-')
        ? selectedLang!.code.split('-').first
        : selectedLang!.code;
    final allModels = SherpaModelDictionary.getModelsForLanguage(
      normalizedCode,
    );
    final availableModels = allModels
        .where((m) => m.model != null)
        .map((m) => m.model!)
        .toList();

    if (availableModels.isEmpty) {
      setState(() {
        _statusMessage = 'No models available for ${selectedLang!.name}';
      });
      return;
    }

    // Use the provided model or default to first available
    final modelsToDownload = model != null ? [model] : availableModels;

    final result = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5), // Transparent overlay
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: ModelDownloadCard(
          requiredModels: modelsToDownload,
          languageCode: selectedLang!.code,
          onAllModelsDownloaded: () {
            Navigator.of(context).pop(true);
          },
        ),
      ),
    );

    if (result == true && mounted && selectedLang != null) {
      // Model downloaded and saved (step-2 saves via TutorService)
      // Reload the saved model preference
      final savedModel = await TutorService.getModelPriority(normalizedCode);
      if (savedModel != null) {
        selectedModel = savedModel;
        await _initializeSherpa();
      } else if (model != null) {
        // Fallback to the downloaded model
        selectedModel = model;
        await TutorService.saveModelPriority(normalizedCode, model);
        await _initializeSherpa();
      } else if (availableModels.isNotEmpty) {
        // Use first available model
        selectedModel = availableModels.first;
        await TutorService.saveModelPriority(
          normalizedCode,
          availableModels.first,
        );
        await _initializeSherpa();
      }
    }
  }

  Future<void> _changeLanguageOrModel(LanguageModelSelection selection) async {
    final lang = selection.language;

    // Update UI immediately to show selection (this happens before menu closes)
    setState(() {
      selectedLang = lang;
      _transcription = 'Press the button to start recording';
      _statusMessage = 'Loading model for ${lang.name}...';
    });

    // Close the menu first by scheduling the processing after the current frame
    // This ensures the menu closes before we start the potentially long-running operation
    await Future.microtask(() async {
      // Small delay to ensure menu closes visually
      await Future.delayed(const Duration(milliseconds: 200));

      if (!mounted) return;

      // Always show download modal with all models for this language
      await _showModelDownloadDialogForLanguage(lang.code);
    });
  }

  void _handleSpeechTranscribed(String transcribedText, int percentage) {
    setState(() {
      _transcription = transcribedText;
      _statusMessage = 'Transcription complete (${percentage}% match)';
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  /// Get the model variant for the selected model to access accuracy/proficiency
  SherpaModelVariant? _getSelectedModelVariant() {
    if (selectedLang == null || selectedModel == null) return null;

    final normalizedCode = selectedLang!.code.contains('-')
        ? selectedLang!.code.split('-').first
        : selectedLang!.code;

    final models = SherpaModelDictionary.getModelsForLanguage(normalizedCode);
    return models.firstWhere(
      (m) => m.model == selectedModel,
      orElse: () => models.first,
    );
  }

  /// Get proficiency/accuracy display text
  String _getProficiencyText(ModelAccuracy accuracy) {
    switch (accuracy) {
      case ModelAccuracy.lowest:
        return 'Basic';
      case ModelAccuracy.low:
        return 'Standard';
      case ModelAccuracy.moderate:
        return 'Good';
      case ModelAccuracy.high:
        return 'High';
      case ModelAccuracy.highest:
        return 'Premium';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Build title with language name and proficiency
    String titleText = 'Sherpa-ONNX STT';
    if (selectedLang != null) {
      titleText = selectedLang!.name;
      final modelVariant = _getSelectedModelVariant();
      if (modelVariant != null) {
        final proficiency = _getProficiencyText(modelVariant.accuracy);
        titleText += ' ($proficiency)';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(titleText),
        actions: [
          // Language selector with grouped list and model sub-items
          PopupMenuButton<LanguageModelSelection>(
            onSelected: _changeLanguageOrModel,
            itemBuilder: (BuildContext context) {
              final groupedLangs = Language.getGroupedLanguages();
              final sortedGroups = groupedLangs.keys.toList()..sort();

              final items = <PopupMenuEntry<LanguageModelSelection>>[];

              for (final groupKey in sortedGroups) {
                final groupLangs = groupedLangs[groupKey]!;

                // Add header using a custom menu item
                items.add(
                  PopupMenuItem<LanguageModelSelection>(
                    enabled: false,
                    child: Text(
                      groupKey,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                );

                // Add languages in this group (simplified - no model sub-items)
                for (final lang in groupLangs) {
                  // Simplified: just show language, no model details
                  items.add(
                    CheckedPopupMenuItem<LanguageModelSelection>(
                      value: LanguageModelSelection(
                        lang,
                        null, // No specific model selected, will show all in modal
                      ),
                      checked: selectedLang?.code == lang.code,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          vertical: 6,
                          horizontal: 4,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(4),
                          color: selectedLang?.code == lang.code
                              ? Colors.blue[50]
                              : Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            Text(
                              lang.flag,
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lang.name,
                                style: TextStyle(
                                  fontWeight: selectedLang?.code == lang.code
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                  color: selectedLang?.code == lang.code
                                      ? Colors.blue[900]
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }

                // Add divider between groups (except last)
                if (groupKey != sortedGroups.last) {
                  items.add(const PopupMenuDivider());
                }
              }

              return items;
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                // Status message
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: _isInitializing
                        ? Colors.orange[50]
                        : _statusMessage.contains('Error')
                        ? Colors.red[50]
                        : Colors.green[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: _isInitializing
                          ? Colors.orange[200]!
                          : _statusMessage.contains('Error')
                          ? Colors.red[200]!
                          : Colors.green[200]!,
                    ),
                  ),
                  child: Row(
                    children: [
                      if (_isInitializing)
                        const Padding(
                          padding: EdgeInsets.only(right: 8.0),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          _statusMessage,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Transcription result
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.blue[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.blue[200]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Transcription:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 200,
                        child: SingleChildScrollView(
                          child: Text(
                            _transcription,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Model and language info
                if (selectedModel != null && selectedLang != null)
                  Text(
                    'Model: ${selectedModel!.displayName} (${selectedModel!.fileSize}) | Language: ${selectedLang!.name} (${selectedLang!.code})',
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 20),
                // STT Button
                if ((selectedModel != null ||
                        selectedCustomModelName != null) &&
                    !_isInitializing)
                  Builder(
                    builder: (context) {
                      print('[main.dart] build: Creating SherpaOnnxSTTButton');
                      print(
                        '[main.dart] build: selectedModel=${selectedModel?.displayName ?? "null"} (${selectedModel?.modelName ?? selectedCustomModelName ?? "none"})',
                      );
                      print(
                        '[main.dart] build: selectedLang=${selectedLang?.name} (${selectedLang?.code})',
                      );
                      print(
                        '[main.dart] build: languageCode=${selectedLang?.code ?? 'en'}',
                      );
                      print(
                        '[main.dart] build: selectedCustomModelName=$selectedCustomModelName',
                      );
                      return Center(
                        child: SherpaOnnxSTTButton(
                          languageCode: selectedLang?.code ?? 'en',
                          sherpaModel: selectedModel,
                          customModelName: selectedCustomModelName,
                          onSpeechTranscribed: _handleSpeechTranscribed,
                          label: 'Press to speak',
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
