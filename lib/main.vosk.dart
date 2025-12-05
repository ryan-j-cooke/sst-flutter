import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vosk_flutter/vosk_flutter.dart';

void main() {
  runApp(const MyApp());
}

// Language models mapping - you can add more models here
const languageModels = {
  'en_US': {
    'name': 'vosk-model-small-en-us-0.15',
    'url':
        'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip',
  },
  'th_TH': {
    'name': 'vosk-v1',
    'url':
        'https://github.com/vistec-AI/commonvoice-th/releases/download/vosk-v1/model.zip',
  },
  'fr_FR': {
    'name': 'vosk-model-small-fr-0.22',
    'url': 'https://alphacephei.com/vosk/models/vosk-model-small-fr-0.22.zip',
  },
  'zh_CN': {
    'name': 'vosk-model-small-cn-0.22',
    'url': 'https://alphacephei.com/vosk/models/vosk-model-small-cn-0.22.zip',
  },
  'ru_RU': {
    'name': 'vosk-model-small-ru-0.22',
    'url': 'https://alphacephei.com/vosk/models/vosk-model-small-ru-0.22.zip',
  },
  'it_IT': {
    'name': 'vosk-model-small-it-0.22',
    'url': 'https://alphacephei.com/vosk/models/vosk-model-small-it-0.22.zip',
  },
  'es_ES': {
    'name': 'vosk-model-small-es-0.22',
    'url': 'https://alphacephei.com/vosk/models/vosk-model-small-es-0.22.zip',
  },
};

const languages = [
  Language('Français', 'fr_FR'),
  Language('English', 'en_US'),
  Language('ไทย', 'th_TH'),
  Language('Chinese', 'zh_CN'),
  Language('Pусский', 'ru_RU'),
  Language('Italiano', 'it_IT'),
  Language('Español', 'es_ES'),
];

class Language {
  final String name;
  final String code;

  const Language(this.name, this.code);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Vosk STT - Multilingual',
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
  final VoskFlutterPlugin _voskPlugin = VoskFlutterPlugin.instance();
  final ModelLoader _modelLoader = ModelLoader();

  Model? _currentModel;
  Recognizer? _recognizer;
  SpeechService? _speechService;

  bool _isLoading = false;
  bool _isListening = false;
  String _transcription = 'Press the button to start listening';
  String _partialText = '';
  String _statusMessage = 'Initializing...';

  Language selectedLang = languages.firstWhere(
    (l) => l.code == 'zh_CN',
    orElse: () => languages[2],
  );

  StreamSubscription<String>? _resultSubscription;
  StreamSubscription<String>? _partialSubscription;

  @override
  void initState() {
    super.initState();
    _initializeModel();
  }

  Future<void> _initializeModel() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Loading model...';
    });

    try {
      String finalModelPath;

      // For Thai, try to load from static asset first
      if (selectedLang.code == 'th_TH') {
        setState(() => _statusMessage = 'Loading Thai model from assets...');
        try {
          final extractedPath = await _modelLoader.loadFromAssets(
            'assets/model.zip',
          );
          // The ZIP contains a 'model' folder, so we need to find the actual model directory
          final foundPath = await _findActualModelPath(extractedPath);
          if (foundPath != null) {
            finalModelPath = foundPath;
            setState(() => _statusMessage = 'Loaded Thai model from assets');
          } else {
            throw Exception(
              'Could not find model files in extracted path: $extractedPath',
            );
          }
        } catch (e) {
          print('Error loading from assets: $e, falling back to local/network');
          // Fall through to local/network loading
          finalModelPath = await _loadModelFromLocalOrNetwork();
        }
      } else {
        // For other languages, use local/network loading
        finalModelPath = await _loadModelFromLocalOrNetwork();
      }

      // Create model
      _currentModel = await _voskPlugin.createModel(finalModelPath);

      // Create recognizer (sample rate 16000 is standard for Vosk)
      _recognizer = await _voskPlugin.createRecognizer(
        model: _currentModel!,
        sampleRate: 16000,
      );

      // Initialize speech service
      _speechService = await _voskPlugin.initSpeechService(_recognizer!);

      // Set up listeners
      _setupListeners();

      setState(() {
        _isLoading = false;
        _statusMessage = 'Ready';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error: $e';
        _transcription = 'Error loading model: $e';
      });
      print('Error initializing model: $e');
    }
  }

  Future<String> _loadModelFromLocalOrNetwork() async {
    // First, try to load from local Documents/model folder
    setState(() => _statusMessage = 'Checking for local model...');
    final modelPath = await _getLocalModelPath(selectedLang.code);

    if (modelPath != null && await Directory(modelPath).exists()) {
      // Verify the model directory contains actual model files
      if (await _isValidModelDirectory(modelPath)) {
        // Use local model
        setState(() => _statusMessage = 'Using local model from:\n$modelPath');
        return modelPath;
      } else {
        // Directory exists but doesn't contain valid model files
        // Try to find model files in subdirectories
        final validPath = await _findModelInSubdirectories(modelPath);
        if (validPath != null) {
          setState(
            () => _statusMessage = 'Using local model from:\n$validPath',
          );
          return validPath;
        }
      }
    }

    // No valid local model found, download from network
    return await _downloadModel(selectedLang.code);
  }

  Future<String> _downloadModel(String langCode) async {
    // Load from network with retry logic
    setState(() => _statusMessage = 'Downloading model from network...');
    final modelInfo = languageModels[langCode];
    if (modelInfo == null) {
      throw Exception('Model not found for language: $langCode');
    }

    // Try to load with retry and force reload if corrupted
    int retries = 2; // Reduced retries
    String? finalModelPathAttempt;
    Exception? lastError;

    for (int i = 0; i < retries; i++) {
      try {
        setState(
          () => _statusMessage =
              'Downloading model... (attempt ${i + 1}/$retries)\nThis may take a few minutes...',
        );
        // Clean up before retry
        if (i > 0) {
          await _cleanupCorruptedModel(modelInfo['name']!);
          await Future.delayed(Duration(seconds: 1));
        }

        finalModelPathAttempt = await _modelLoader
            .loadFromNetwork(
              modelInfo['url']!,
              forceReload:
                  i > 0, // Force reload on retry to clear corrupted files
            )
            .timeout(
              Duration(minutes: 10),
              onTimeout: () {
                throw TimeoutException(
                  'Model download timed out after 10 minutes',
                );
              },
            );
        break; // Success, exit retry loop
      } catch (e) {
        lastError = e is Exception ? e : Exception(e.toString());
        print('Model download attempt ${i + 1} failed: $e');
        if (i < retries - 1) {
          // Wait before retry
          await Future.delayed(Duration(seconds: 3));
        }
      }
    }

    if (finalModelPathAttempt == null) {
      // Provide helpful error message
      final errorMsg = lastError?.toString() ?? 'Unknown error';
      if (errorMsg.contains('End of Central Directory') ||
          errorMsg.contains('FormatException')) {
        final documentsDir = await getApplicationDocumentsDirectory();
        throw Exception(
          'Download failed: Corrupted ZIP file.\n\n'
          'Possible causes:\n'
          '• Network interruption\n'
          '• Server issues\n'
          '• Insufficient storage\n\n'
          'Solutions:\n'
          '1. Check your internet connection\n'
          '2. Try again later\n'
          '3. Download manually:\n'
          '   - URL: ${modelInfo['url']!}\n'
          '   - Extract to: ${documentsDir.path}/models/${modelInfo['name']!}\n\n'
          'Then restart the app.',
        );
      }
      throw lastError ??
          Exception('Failed to download model after $retries attempts');
    }

    return finalModelPathAttempt;
  }

  Future<String?> _getLocalModelPath(String langCode) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      // Check both possible locations: Documents/model (user's folder) and Documents/models (ModelLoader default)
      final possibleDirs = [
        Directory('${documentsDir.path}/model'),
        Directory('${documentsDir.path}/models'),
      ];

      for (final modelDir in possibleDirs) {
        if (await modelDir.exists()) {
          // Check for model folder matching the language
          final modelInfo = languageModels[langCode];
          if (modelInfo != null) {
            final modelName = modelInfo['name']!;
            final potentialPath = '${modelDir.path}/$modelName';
            if (await Directory(potentialPath).exists()) {
              // Verify this directory contains model files
              if (await _isValidModelDirectory(potentialPath)) {
                return potentialPath;
              }
              // If not, check subdirectories
              final subDirs = await Directory(potentialPath)
                  .list()
                  .where((item) => item is Directory)
                  .cast<Directory>()
                  .toList();
              for (var subDir in subDirs) {
                if (await _isValidModelDirectory(subDir.path)) {
                  return subDir.path;
                }
              }
            }
            // Also check if the model folder itself contains the model
            final contents = await modelDir.list().toList();
            for (var item in contents) {
              if (item is Directory) {
                final itemPath = item.path;
                // Check if this directory or its name contains the model name
                if (itemPath.contains(modelName) ||
                    itemPath.contains('model') ||
                    itemPath.contains(langCode.toLowerCase().split('_')[0])) {
                  if (await _isValidModelDirectory(itemPath)) {
                    return itemPath;
                  }
                  // Check subdirectories
                  try {
                    final subDirs = await Directory(itemPath)
                        .list()
                        .where((item) => item is Directory)
                        .cast<Directory>()
                        .toList();
                    for (var subDir in subDirs) {
                      if (await _isValidModelDirectory(subDir.path)) {
                        return subDir.path;
                      }
                    }
                  } catch (e) {
                    // Ignore errors when checking subdirectories
                  }
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error checking local model: $e');
    }
    return null;
  }

  /// Check if a directory contains valid Vosk model files
  /// A valid Vosk model directory should contain subdirectories like am/, conf/, graph/, ivector/
  Future<bool> _isValidModelDirectory(String path) async {
    try {
      final dir = Directory(path);
      if (!await dir.exists()) return false;

      final contents = await dir.list().toList();

      // Vosk models typically contain subdirectories: am, conf, graph, ivector
      // We need to check for these directories, not files
      final requiredDirs = ['am', 'conf', 'graph'];
      final dirNames = contents
          .where((f) => f is Directory)
          .map((f) => (f as Directory).path.split('/').last.toLowerCase())
          .toSet();

      // Check if at least some required model directories exist
      // A valid model should have at least 2 of these directories
      final foundDirs = requiredDirs
          .where((req) => dirNames.contains(req))
          .length;

      // Also check for files that might indicate a model (fallback for different structures)
      final fileNames = contents
          .where((f) => f is File)
          .map((f) => (f as File).path.split('/').last.toLowerCase())
          .toSet();

      final hasModelFiles = fileNames.any(
        (name) =>
            name.endsWith('.conf') ||
            name.endsWith('.am') ||
            name.endsWith('.fst') ||
            name == 'mfcc.conf',
      );

      // Valid if we have at least 2 required directories OR model files
      return foundDirs >= 2 || hasModelFiles;
    } catch (e) {
      return false;
    }
  }

  /// Recursively search for model files in subdirectories
  Future<String?> _findModelInSubdirectories(String basePath) async {
    try {
      final dir = Directory(basePath);
      if (!await dir.exists()) return null;

      final contents = await dir.list().toList();
      for (var item in contents) {
        if (item is Directory) {
          final subPath = item.path;
          if (await _isValidModelDirectory(subPath)) {
            return subPath;
          }
          // Recursively search deeper (max 2 levels to avoid infinite loops)
          final deeper = await _findModelInSubdirectories(subPath);
          if (deeper != null) return deeper;
        }
      }
    } catch (e) {
      print('Error searching subdirectories: $e');
    }
    return null;
  }

  /// Find the actual model path from an extracted path
  /// The ZIP might extract to a folder that contains another 'model' folder
  /// Returns the directory that contains am/, conf/, graph/ subdirectories
  Future<String?> _findActualModelPath(String extractedPath) async {
    // First check if the extracted path itself is valid (contains model subdirectories)
    if (await _isValidModelDirectory(extractedPath)) {
      return extractedPath;
    }

    // Check for common patterns: extractedPath/model, extractedPath/model/model, etc.
    final possiblePaths = [
      extractedPath,
      '$extractedPath/model',
      '$extractedPath/model/model',
    ];

    for (final path in possiblePaths) {
      if (await Directory(path).exists()) {
        // Check if this path itself is valid (contains model subdirectories)
        if (await _isValidModelDirectory(path)) {
          return path;
        }
      }
    }

    // If not found in common patterns, search one level deep but don't go into subdirectories
    // We want the parent directory that contains am/, conf/, graph/, not those subdirectories themselves
    try {
      final dir = Directory(extractedPath);
      if (await dir.exists()) {
        final contents = await dir.list().toList();
        for (var item in contents) {
          if (item is Directory) {
            final subPath = item.path;
            // Check if this subdirectory is a model directory (contains am/, conf/, graph/)
            if (await _isValidModelDirectory(subPath)) {
              return subPath;
            }
          }
        }
      }
    } catch (e) {
      print('Error searching for model path: $e');
    }

    return null;
  }

  Future<void> _cleanupCorruptedModel(String modelName) async {
    try {
      final documentsDir = await getApplicationDocumentsDirectory();
      // Check both possible locations
      final possibleDirs = [
        Directory('${documentsDir.path}/model'),
        Directory('${documentsDir.path}/models'),
      ];

      for (final modelDir in possibleDirs) {
        if (await modelDir.exists()) {
          final contents = modelDir.listSync();
          for (var item in contents) {
            if (item is Directory && item.path.contains(modelName)) {
              try {
                await item.delete(recursive: true);
                print('Cleaned up corrupted model: ${item.path}');
              } catch (e) {
                print('Error cleaning up model: $e');
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error in cleanup: $e');
    }
  }

  void _setupListeners() {
    if (_speechService == null) return;

    _resultSubscription?.cancel();
    _partialSubscription?.cancel();

    _resultSubscription = _speechService!.onResult().listen((result) {
      setState(() {
        _transcription = result;
        _partialText = '';
      });
    });

    _partialSubscription = _speechService!.onPartial().listen((partial) {
      setState(() {
        _partialText = partial;
      });
    });
  }

  Future<void> _startListening() async {
    if (_speechService == null) {
      await _initializeModel();
      if (_speechService == null) return;
    }

    try {
      final started = await _speechService!.start();
      if (started == true) {
        setState(() {
          _isListening = true;
          _transcription = 'Listening...';
          _partialText = '';
        });
      }
    } catch (e) {
      print('Error starting recognition: $e');
      setState(() {
        _isListening = false;
        _statusMessage = 'Error: $e';
      });
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speechService?.stop();
      setState(() {
        _isListening = false;
      });
    } catch (e) {
      print('Error stopping recognition: $e');
    }
  }

  Future<void> _pauseListening() async {
    try {
      await _speechService?.setPause(paused: true);
    } catch (e) {
      print('Error pausing recognition: $e');
    }
  }

  Future<void> _resumeListening() async {
    try {
      await _speechService?.setPause(paused: false);
    } catch (e) {
      print('Error resuming recognition: $e');
    }
  }

  Future<void> _changeLanguage(Language lang) async {
    if (lang.code == selectedLang.code) return;

    setState(() {
      selectedLang = lang;
      _isListening = false;
    });

    // Stop current service
    await _speechService?.dispose();
    _resultSubscription?.cancel();
    _partialSubscription?.cancel();
    _currentModel = null;
    _recognizer = null;
    _speechService = null;

    // Initialize with new language
    await _initializeModel();
  }

  @override
  void dispose() {
    _resultSubscription?.cancel();
    _partialSubscription?.cancel();
    _speechService?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Vosk STT - Multilingual'),
        actions: [
          PopupMenuButton<Language>(
            onSelected: _changeLanguage,
            itemBuilder: (BuildContext context) => languages
                .map(
                  (l) => CheckedPopupMenuItem<Language>(
                    value: l,
                    checked: selectedLang == l,
                    child: Text(l.name),
                  ),
                )
                .toList(),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              // Status message
              Container(
                padding: const EdgeInsets.all(12.0),
                decoration: BoxDecoration(
                  color: _isLoading
                      ? Colors.orange[50]
                      : _statusMessage.contains('Error')
                      ? Colors.red[50]
                      : Colors.green[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _isLoading
                        ? Colors.orange[200]!
                        : _statusMessage.contains('Error')
                        ? Colors.red[200]!
                        : Colors.green[200]!,
                  ),
                ),
                child: Row(
                  children: [
                    if (_isLoading)
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
              // Final result
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
                      'Final Result:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 100,
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
              // Partial result
              if (_partialText.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Partial Result:',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 60,
                        child: SingleChildScrollView(
                          child: Text(
                            _partialText,
                            style: const TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 32),
              Text(
                'Language: ${selectedLang.name} (${selectedLang.code})',
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _isLoading
                    ? null
                    : (_isListening ? _stopListening : _startListening),
                icon: Icon(_isListening ? Icons.stop : Icons.mic, size: 24),
                label: Text(
                  _isListening ? 'Stop Listening' : 'Start Listening',
                  style: const TextStyle(fontSize: 18),
                ),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  backgroundColor: _isListening ? Colors.red : Colors.green,
                  foregroundColor: Colors.white,
                ),
              ),
              if (_isListening) ...[
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pauseListening,
                      icon: const Icon(Icons.pause, size: 20),
                      label: const Text('Pause'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _resumeListening,
                      icon: const Icon(Icons.play_arrow, size: 20),
                      label: const Text('Resume'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
