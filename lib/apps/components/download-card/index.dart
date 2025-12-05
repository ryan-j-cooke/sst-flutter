import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import '../cards/index.dart';
import '../../../utils/sherpa-onxx-sst.dart';
import '../../../utils/sherpa-model-dictionary.dart';
import '../../../utils/file.dart';
import './download-list-item.dart';
import './step-1.dart';
import './step-2.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

// Export CancellationToken for use in this file
export '../../../utils/file.dart' show CancellationToken;
// Export ModelInfo and ModelDownloadStatus for use in other files
export './download-list-item.dart' show ModelInfo, ModelDownloadStatus;

/// Model Download Card Component
///
/// Displays a list of Sherpa-ONNX models that need to be downloaded.
/// Shows download progress and only allows proceeding when all required models are downloaded.
class ModelDownloadCard extends StatefulWidget {
  final List<SherpaModelType> requiredModels;
  final VoidCallback? onAllModelsDownloaded;
  final String? languageCode;

  const ModelDownloadCard({
    super.key,
    required this.requiredModels,
    this.onAllModelsDownloaded,
    this.languageCode,
  });

  @override
  State<ModelDownloadCard> createState() => _ModelDownloadCardState();
}

class _ModelDownloadCardState extends State<ModelDownloadCard> {
  final Map<String, ModelInfo> _modelInfos =
      {}; // Keyed by modelName (works for both enum and custom)
  final Map<String, CancellationToken> _cancelTokens = {}; // Keyed by modelName
  bool _isInitializing = true;
  bool _isDownloadingAll = false;
  int _currentStep = 0;
  List<SherpaModelType> _actualModels = []; // Enum models for step-2
  List<SherpaModelVariant> _allModelVariants =
      []; // All models (enum + custom) for display

  @override
  void initState() {
    super.initState();
    _initializeModels();
  }

  Future<void> _initializeModels() async {
    setState(() {
      _isInitializing = true;
    });

    // If requiredModels is empty but languageCode is provided, fetch models from dictionary
    List<SherpaModelType> enumModelsToCheck = widget.requiredModels;
    if (enumModelsToCheck.isEmpty && widget.languageCode != null) {
      print(
        '[download-card] _initializeModels: Fetching models for languageCode=${widget.languageCode}',
      );
      final allModels = SherpaModelDictionary.getModelsForLanguage(
        widget.languageCode!,
      );
      _allModelVariants = allModels;

      // Get enum models for step-2
      enumModelsToCheck = allModels
          .where((m) => m.model != null)
          .map((m) => m.model!)
          .toList();
      print(
        '[download-card] _initializeModels: Found ${enumModelsToCheck.length} enum models and ${allModels.length - enumModelsToCheck.length} custom models for ${widget.languageCode}',
      );
      // Store for later use
      _actualModels = enumModelsToCheck;
    } else {
      _actualModels = enumModelsToCheck;
      // If we have requiredModels, create variants for them
      _allModelVariants = enumModelsToCheck
          .map(
            (m) => SherpaModelVariant(
              model: m,
              accuracy: ModelAccuracy.moderate, // Default
              speed: ModelSpeed.moderate, // Default
              fileSize: m.fileSize,
              modelName: m.modelName,
              displayName: m.displayName,
              isCurrent: false,
            ),
          )
          .toList();
    }

    if (_allModelVariants.isEmpty) {
      print('[download-card] _initializeModels: No models to check');
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
      return;
    }

    // Get all model names (both enum and custom) for existence checks
    final allModelNames = _allModelVariants.map((v) => v.modelName).toList();

    // Check model existence using the same method as debug (ensures consistency)
    // Run checks in parallel to avoid blocking UI
    final modelExistenceChecks = await Future.wait(
      allModelNames.map((modelName) async {
        final exists = await SherpaOnnxSTTHelper.modelExistsByName(modelName);
        return MapEntry(modelName, exists);
      }),
    );
    final modelFilesExist = Map<String, bool>.fromEntries(modelExistenceChecks);

    // Check for .tar.bz2 files in parallel
    final tempDir = await getTemporaryDirectory();
    final tarBz2Checks = await Future.wait(
      allModelNames.map((modelName) async {
        final tarBz2File = File('${tempDir.path}/$modelName.tar.bz2');
        final exists = await tarBz2File.exists();
        return MapEntry(modelName, exists);
      }),
    );
    final tarBz2Exists = Map<String, bool>.fromEntries(tarBz2Checks);

    // Update model infos with results from isolate (for all variants)
    for (final variant in _allModelVariants) {
      final modelName = variant.modelName;
      final modelFilesExistForModel = modelFilesExist[modelName] ?? false;
      final tarBz2ExistsForModel = tarBz2Exists[modelName] ?? false;

      // If model files exist, it's downloaded
      // If .tar.bz2 exists but model files don't, it needs extraction (show as notDownloaded, but downloadModel will handle it)
      _modelInfos[modelName] = ModelInfo(
        model: variant.model,
        customModelName: variant.customModelName,
        displayName: variant.displayName,
        fileSize: variant.fileSize,
        status: modelFilesExistForModel
            ? ModelDownloadStatus.downloaded
            : ModelDownloadStatus.notDownloaded,
        hasCompressedFile: tarBz2ExistsForModel && !modelFilesExistForModel,
      );

      // Log status for debugging
      print(
        '[download-card] _initializeModels: Model=${variant.displayName} (${modelName})',
      );
      print(
        '[download-card] _initializeModels: modelFilesExistForModel=$modelFilesExistForModel, tarBz2ExistsForModel=$tarBz2ExistsForModel',
      );
      if (modelFilesExistForModel) {
        print(
          '[download-card] _initializeModels: ✓ Model ${variant.displayName} is downloaded and ready',
        );
      } else if (tarBz2ExistsForModel && !modelFilesExistForModel) {
        print(
          '[download-card] _initializeModels: Model ${variant.displayName} has .tar.bz2 file but model files missing - will extract on download',
        );
      } else {
        print(
          '[download-card] _initializeModels: ✗ Model ${variant.displayName} is not downloaded',
        );
      }
    }

    if (mounted) {
      setState(() {
        _isInitializing = false;
      });

      // If models are already downloaded, automatically move to step 2
      // Don't call _checkAllDownloaded() here as it would close the dialog
      if (_areRequiredModelsDownloaded() && _currentStep == 0) {
        print(
          '[download-card] _initializeModels: Models already downloaded, moving to step 2',
        );
        setState(() {
          _currentStep = 1;
        });
      }
    }
  }

  /// Check model existence in an isolate to avoid blocking UI (using enum models)
  Future<Map<String, dynamic>> _checkModelsExistInIsolate(
    List<SherpaModelType> models,
  ) async {
    return _checkModelsExistInIsolateByName(
      models.map((m) => m.modelName).toList(),
    );
  }

  /// Check model existence in an isolate to avoid blocking UI (using model names)
  Future<Map<String, dynamic>> _checkModelsExistInIsolateByName(
    List<String> modelNames,
  ) async {
    // Create receive port for isolate communication
    final receivePort = ReceivePort();

    // Spawn isolate to check model existence
    await Isolate.spawn(_checkModelsExistIsolate, {
      'sendPort': receivePort.sendPort,
      'modelNames': modelNames,
    });

    // Wait for result from isolate
    final result = await receivePort.first as Map<String, dynamic>;
    return result;
  }

  /// Isolate entry point for checking model existence
  static Future<void> _checkModelsExistIsolate(
    Map<String, dynamic> params,
  ) async {
    final sendPort = params['sendPort'] as SendPort;
    final modelNames = params['modelNames'] as List<String>;

    try {
      final results = <String, bool>{};
      final tarBz2Exists = <String, bool>{};

      // Get directories
      final documentsDir = await getApplicationDocumentsDirectory();
      final baseModelDir = '${documentsDir.path}/sherpa_onnx_models';
      final tempDir = await getTemporaryDirectory();

      // Check each model
      for (final modelName in modelNames) {
        final modelDir = '$baseModelDir/$modelName';

        // Determine model type
        final isWhisperModel = modelName.contains('whisper');
        final isParaformerModel = modelName.contains('paraformer');
        final isNemoModel = modelName.contains('nemo');

        bool modelFilesExist = false;

        if (isParaformerModel || isNemoModel) {
          // Paraformer and NeMo models use a single model.onnx file
          final modelFile = File('$modelDir/model.onnx');
          final tokensFile = File('$modelDir/tokens.txt');

          final modelExists = await modelFile.exists();
          final tokensExists = await tokensFile.exists();

          modelFilesExist = modelExists && tokensExists;

          print('[download-card] _checkModelsExistIsolate: Model=$modelName (${isParaformerModel ? "Paraformer" : "NeMo"})');
          print(
            '[download-card] _checkModelsExistIsolate: model.onnx exists=$modelExists, tokensExists=$tokensExists',
          );
          print(
            '[download-card] _checkModelsExistIsolate: modelFilesExist=$modelFilesExist',
          );
        } else {
          // Transducer/Zipformer models use encoder/decoder/joiner files
          final encoderFile = File('$modelDir/encoder.onnx');
          final decoderFile = File('$modelDir/decoder.onnx');
          final joinerFile = File('$modelDir/joiner.onnx');
          final tokensFile = File('$modelDir/tokens.txt');

          final encoderExists = await encoderFile.exists();
          final decoderExists = await decoderFile.exists();
          final joinerExists = await joinerFile.exists();
          final tokensExists = await tokensFile.exists();

          // For Whisper models, joiner is not required
          modelFilesExist =
              encoderExists &&
              decoderExists &&
              tokensExists &&
              (isWhisperModel || joinerExists);

          print('[download-card] _checkModelsExistIsolate: Model=$modelName (${isWhisperModel ? "Whisper" : "Transducer/Zipformer"})');
          print(
            '[download-card] _checkModelsExistIsolate: encoderExists=$encoderExists, decoderExists=$decoderExists, joinerExists=$joinerExists, tokensExists=$tokensExists',
          );
          print(
            '[download-card] _checkModelsExistIsolate: isWhisperModel=$isWhisperModel',
          );
          print(
            '[download-card] _checkModelsExistIsolate: modelFilesExist=$modelFilesExist',
          );
        }

        results[modelName] = modelFilesExist;

        // Also check if .tar.bz2 file exists (for cases where download completed but extraction didn't)
        if (!modelFilesExist) {
          final tarBz2File = File('${tempDir.path}/$modelName.tar.bz2');
          tarBz2Exists[modelName] = await tarBz2File.exists();
        } else {
          tarBz2Exists[modelName] = false;
        }
      }

      sendPort.send({'modelFilesExist': results, 'tarBz2Exists': tarBz2Exists});
    } catch (e) {
      // On error, return all false
      final results = <String, bool>{};
      final tarBz2Exists = <String, bool>{};
      for (final modelName in modelNames) {
        results[modelName] = false;
        tarBz2Exists[modelName] = false;
      }
      sendPort.send({'modelFilesExist': results, 'tarBz2Exists': tarBz2Exists});
    }
  }

  bool _areAllModelsDownloaded() {
    return _modelInfos.values.every(
      (info) => info.status == ModelDownloadStatus.downloaded,
    );
  }

  /// Check if all models are either downloading or downloaded
  bool _areAllModelsDownloadingOrDownloaded() {
    return _modelInfos.values.every(
      (info) =>
          info.status == ModelDownloadStatus.downloading ||
          info.status == ModelDownloadStatus.downloaded,
    );
  }

  /// Check if at least one model is downloaded (required for step 2)
  /// For Sherpa-ONNX, we just need any model to be downloaded and extracted
  bool _areRequiredModelsDownloaded() {
    // Check if at least one model is downloaded
    return _modelInfos.values.any(
      (info) => info.status == ModelDownloadStatus.downloaded,
    );
  }

  /// Refresh status for a specific model by checking if files exist
  Future<void> _refreshModelStatus(ModelInfo modelInfo) async {
    final modelName = modelInfo.modelName;
    final modelExists = await SherpaOnnxSTTHelper.modelExistsByName(modelName);

    if (mounted) {
      setState(() {
        if (modelExists && modelInfo.status != ModelDownloadStatus.downloaded) {
          modelInfo.status = ModelDownloadStatus.downloaded;
          modelInfo.hasCompressedFile = false;
          modelInfo.statusMessage = null;
          print(
            '[download-card] _refreshModelStatus: Updated status to downloaded for $modelName',
          );
        } else if (!modelExists &&
            modelInfo.status == ModelDownloadStatus.downloaded) {
          // If files don't exist but status says downloaded, reset it
          modelInfo.status = ModelDownloadStatus.notDownloaded;
          print(
            '[download-card] _refreshModelStatus: Reset status to notDownloaded for $modelName',
          );
        }
      });
    }
  }

  /// Check if any downloads are currently in progress
  bool _hasActiveDownloads() {
    return _modelInfos.values.any(
          (info) => info.status == ModelDownloadStatus.downloading,
        ) ||
        _isDownloadingAll;
  }

  /// Check if user can progress to step 2
  bool _canProgressToStep2() {
    return _areRequiredModelsDownloaded() && !_hasActiveDownloads();
  }

  void _checkAllDownloaded() {
    if (_areAllModelsDownloaded() && widget.onAllModelsDownloaded != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        widget.onAllModelsDownloaded?.call();
      });
    }
    // Don't auto-advance - let user click "Next" button manually
  }

  /// Download a single model
  Future<void> _downloadModel(ModelInfo modelInfo) async {
    if (modelInfo.status == ModelDownloadStatus.downloading ||
        modelInfo.status == ModelDownloadStatus.downloaded) {
      print(
        '[download-card] _downloadModel: Model ${modelInfo.displayName} is already downloading or downloaded, skipping',
      );
      return;
    }

    print(
      '[download-card] _downloadModel: ========== Starting download for model ==========',
    );
    final modelName = modelInfo.modelName;
    print(
      '[download-card] _downloadModel: Model=${modelInfo.displayName} ($modelName)',
    );
    print('[download-card] _downloadModel: File size=${modelInfo.fileSize}');
    print(
      '[download-card] _downloadModel: Has compressed file=${modelInfo.hasCompressedFile}',
    );

    // Create cancellation token for this download
    final cancelToken = CancellationToken();
    _cancelTokens[modelName] = cancelToken;

    setState(() {
      modelInfo.status = ModelDownloadStatus.downloading;
      modelInfo.downloadedBytes = 0;
      modelInfo.totalBytes = null;
      modelInfo.errorMessage = null;
      modelInfo.statusMessage = null; // Clear previous status message
    });

    try {
      // Get model directory - use getModelPath for enum models, construct for custom
      final documentsDir = await getApplicationDocumentsDirectory();
      final modelDir = '${documentsDir.path}/sherpa_onnx_models/$modelName';
      print(
        '[download-card] _downloadModel: Model directory destination=$modelDir',
      );
      await Directory(modelDir).create(recursive: true);
      print('[download-card] _downloadModel: Model directory created/verified');

      bool downloadComplete = false;

      // Use downloadModel for enum models, downloadModelByName for custom models
      if (modelInfo.model != null) {
        await SherpaOnnxSTTHelper.downloadModel(
          modelInfo.model!,
          modelDir,
          onProgress: (downloaded, total) {
            if (mounted && !cancelToken.isCancelled) {
              setState(() {
                modelInfo.downloadedBytes = downloaded;
                modelInfo.totalBytes = total;

                // When download reaches 100%, reset progress to show extraction phase
                // This stops the download indicator from showing 100% while extraction continues
                if (total != null && downloaded >= total && !downloadComplete) {
                  downloadComplete = true;
                  // Reset progress indicators - extraction will be shown separately
                  modelInfo.downloadedBytes = 0;
                  modelInfo.totalBytes = null;
                }
              });
            }
          },
          onExtractionProgress: (progress, status) {
            // Update UI during extraction phase with status message
            // Keep status as downloading during extraction
            if (mounted && !cancelToken.isCancelled) {
              setState(() {
                // Update status message to show extraction progress
                modelInfo.statusMessage = status;
              });
            }
          },
          cancelToken: cancelToken,
        );
      } else {
        // Custom model - use downloadModelByName
        await SherpaOnnxSTTHelper.downloadModelByName(
          modelName,
          modelDir,
          displayName: modelInfo.displayName,
          onProgress: (downloaded, total) {
            if (mounted && !cancelToken.isCancelled) {
              setState(() {
                modelInfo.downloadedBytes = downloaded;
                modelInfo.totalBytes = total;

                // When download reaches 100%, reset progress to show extraction phase
                // This stops the download indicator from showing 100% while extraction continues
                if (total != null && downloaded >= total && !downloadComplete) {
                  downloadComplete = true;
                  // Reset progress indicators - extraction will be shown separately
                  modelInfo.downloadedBytes = 0;
                  modelInfo.totalBytes = null;
                }
              });
            }
          },
          onExtractionProgress: (progress, status) {
            // Update UI during extraction phase with status message
            // Keep status as downloading during extraction
            if (mounted && !cancelToken.isCancelled) {
              setState(() {
                // Update status message to show extraction progress
                modelInfo.statusMessage = status;
              });
            }
          },
          cancelToken: cancelToken,
        );
      }

      if (mounted && !cancelToken.isCancelled) {
        setState(() {
          modelInfo.status = ModelDownloadStatus.downloaded;
          // Reset progress indicators since download+extraction is complete
          modelInfo.downloadedBytes = 0;
          modelInfo.totalBytes = null;
          modelInfo.statusMessage = null; // Clear status message when complete
          modelInfo.hasCompressedFile =
              false; // Model files now exist, no longer need extraction
        });
        _checkAllDownloaded();

        // Don't auto-advance - user must click "Next" button manually
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('cancelled')) {
          setState(() {
            modelInfo.status = ModelDownloadStatus.notDownloaded;
            modelInfo.downloadedBytes = 0;
            modelInfo.totalBytes = null;
            modelInfo.errorMessage = null;
            modelInfo.statusMessage = null; // Clear status message on cancel
          });
        } else {
          setState(() {
            modelInfo.status = ModelDownloadStatus.error;
            modelInfo.errorMessage = e.toString();
            modelInfo.statusMessage = null; // Clear status message on error
          });
        }
      }
    } finally {
      _cancelTokens.remove(modelName);
    }
  }

  /// Cancel a model download
  void _cancelDownload(ModelInfo modelInfo) {
    final cancelToken = _cancelTokens[modelInfo.modelName];
    if (cancelToken != null) {
      cancelToken.cancel();
      setState(() {
        modelInfo.status = ModelDownloadStatus.notDownloaded;
        modelInfo.downloadedBytes = 0;
        modelInfo.totalBytes = null;
        modelInfo.errorMessage = null;
        modelInfo.statusMessage = null; // Clear status message on cancel
      });
      _cancelTokens.remove(modelInfo.model);
    }
  }

  /// Download all models that are not yet downloaded, in parallel
  Future<void> _downloadAllModels() async {
    if (_isDownloadingAll) return;

    // Get all models that need to be downloaded
    final modelsToDownload = _modelInfos.values
        .where(
          (info) =>
              info.status != ModelDownloadStatus.downloaded &&
              info.status != ModelDownloadStatus.downloading,
        )
        .toList();

    if (modelsToDownload.isEmpty) {
      _checkAllDownloaded();
      return;
    }

    setState(() {
      _isDownloadingAll = true;
    });

    // Reset all non-downloaded models to downloading state
    for (final modelInfo in modelsToDownload) {
      setState(() {
        modelInfo.status = ModelDownloadStatus.downloading;
        modelInfo.downloadedBytes = 0;
        modelInfo.totalBytes = null;
        modelInfo.errorMessage = null;
        modelInfo.statusMessage = null; // Clear previous status message
      });
    }

    // Download all models in parallel
    final downloadFutures = modelsToDownload.map((modelInfo) async {
      final modelName = modelInfo.modelName;
      // Create cancellation token for this download
      final cancelToken = CancellationToken();
      _cancelTokens[modelName] = cancelToken;

      try {
        // Get model directory - use getModelPath for enum models, construct for custom
        final documentsDir = await getApplicationDocumentsDirectory();
        final modelDir = '${documentsDir.path}/sherpa_onnx_models/$modelName';
        await Directory(modelDir).create(recursive: true);

        // Use downloadModel for enum models, downloadModelByName for custom models
        if (modelInfo.model != null) {
          await SherpaOnnxSTTHelper.downloadModel(
            modelInfo.model!,
            modelDir,
            onProgress: (downloaded, total) {
              if (mounted && !cancelToken.isCancelled) {
                setState(() {
                  modelInfo.downloadedBytes = downloaded;
                  modelInfo.totalBytes = total;
                });
              }
            },
            onExtractionProgress: (progress, status) {
              // Update UI during extraction phase with status message
              if (mounted && !cancelToken.isCancelled) {
                setState(() {
                  // Update status message to show extraction progress
                  modelInfo.statusMessage = status;
                });
              }
            },
            cancelToken: cancelToken,
          );
        } else {
          // Custom model - use downloadModelByName
          await SherpaOnnxSTTHelper.downloadModelByName(
            modelName,
            modelDir,
            displayName: modelInfo.displayName,
            onProgress: (downloaded, total) {
              if (mounted && !cancelToken.isCancelled) {
                setState(() {
                  modelInfo.downloadedBytes = downloaded;
                  modelInfo.totalBytes = total;
                });
              }
            },
            onExtractionProgress: (progress, status) {
              // Update UI during extraction phase with status message
              if (mounted && !cancelToken.isCancelled) {
                setState(() {
                  // Update status message to show extraction progress
                  modelInfo.statusMessage = status;
                });
              }
            },
            cancelToken: cancelToken,
          );
        }

        if (mounted && !cancelToken.isCancelled) {
          setState(() {
            modelInfo.status = ModelDownloadStatus.downloaded;
            modelInfo.statusMessage =
                null; // Clear status message when complete
            modelInfo.hasCompressedFile =
                false; // Model files now exist, no longer need extraction
          });

          // Don't auto-advance - user must click "Next" button manually
        }
      } catch (e) {
        if (mounted) {
          if (e.toString().contains('cancelled')) {
            setState(() {
              modelInfo.status = ModelDownloadStatus.notDownloaded;
              modelInfo.downloadedBytes = 0;
              modelInfo.totalBytes = null;
              modelInfo.errorMessage = null;
              modelInfo.statusMessage = null; // Clear status message on cancel
            });
          } else {
            setState(() {
              modelInfo.status = ModelDownloadStatus.error;
              modelInfo.errorMessage = e.toString();
            });
          }
        }
      } finally {
        _cancelTokens.remove(modelName);
      }
    });

    // Wait for all downloads to complete (or fail)
    await Future.wait(downloadFutures);

    if (mounted) {
      setState(() {
        _isDownloadingAll = false;
      });
      _checkAllDownloaded();
    }
  }

  String _getProgressText(ModelInfo info) {
    if (info.status == ModelDownloadStatus.downloading) {
      return FileDownloadHelper.getProgressText(
        info.downloadedBytes,
        info.totalBytes,
      );
    }

    return '';
  }

  String _getFileSizeText(ModelInfo info) {
    if (info.status == ModelDownloadStatus.downloading) {
      final progressText = _getProgressText(info);
      return '${info.fileSize} - $progressText';
    }
    return info.fileSize;
  }

  Widget _buildStep1Content() {
    return Step1Content(
      modelInfos: _modelInfos,
      isDownloadingAll: _isDownloadingAll,
      areAllModelsDownloaded: _areAllModelsDownloaded(),
      areAllModelsDownloadingOrDownloaded:
          _areAllModelsDownloadingOrDownloaded(),
      canProgressToStep2: _canProgressToStep2(),
      getFileSizeText: _getFileSizeText,
      onDownloadAll: _downloadAllModels,
      onProgressToStep2: () {
        setState(() {
          _currentStep = 1;
        });
      },
      onDownloadModel: _downloadModel,
      onCancelDownload: _cancelDownload,
      onDeleteModel: _deleteModel,
      onRefreshStatus: _refreshModelStatus,
    );
  }

  Widget _buildStep2Content() {
    return Step2Content(
      canProceed: _areRequiredModelsDownloaded(),
      languageCode: widget.languageCode ?? 'en',
      availableModels: _allModelVariants, // Pass all models (enum + custom)
      onSaveComplete: () {
        // When save is complete, trigger the transition to begin session
        if (widget.onAllModelsDownloaded != null) {
          widget.onAllModelsDownloaded?.call();
        }
      },
    );
  }

  Widget _buildHorizontalStepIndicator() {
    final step1Complete = _areRequiredModelsDownloaded();
    final step1Active = _currentStep == 0;
    final step2Active = _currentStep == 1;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Step 1 circle
        GestureDetector(
          onTap: () {
            setState(() {
              _currentStep = 0;
            });
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: step1Active
                  ? Colors.blue[700]
                  : step1Complete
                  ? Colors.green[700]
                  : Colors.grey[400],
            ),
            child: Center(
              child: step1Complete
                  ? Icon(Icons.check, color: Colors.white, size: 20)
                  : Text(
                      '1',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
            ),
          ),
        ),
        // Connector line
        Container(
          width: 40,
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: step1Complete ? Colors.green[700] : Colors.grey[300],
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        // Step 2 circle
        GestureDetector(
          onTap: _canProgressToStep2()
              ? () {
                  setState(() {
                    _currentStep = 1;
                  });
                }
              : null,
          child: Opacity(
            opacity: _canProgressToStep2() ? 1.0 : 0.5,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: step2Active
                    ? Colors.blue[700]
                    : _canProgressToStep2() && !step2Active
                    ? Colors.green[700]
                    : Colors.grey[400],
              ),
              child: Center(
                child: step2Active && _canProgressToStep2()
                    ? Icon(Icons.check, color: Colors.white, size: 20)
                    : Text(
                        '2',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Delete a model file and update the UI
  Future<void> _deleteModel(ModelInfo modelInfo) async {
    if (modelInfo.status == ModelDownloadStatus.downloading) {
      return; // Don't allow deletion while downloading
    }

    try {
      // Get model directory - use getModelPath for enum models, construct for custom
      final documentsDir = await getApplicationDocumentsDirectory();
      final modelName = modelInfo.modelName;
      final modelDir = '${documentsDir.path}/sherpa_onnx_models/$modelName';
      final modelDirFile = Directory(modelDir);

      // Delete the entire model directory
      if (await modelDirFile.exists()) {
        await modelDirFile.delete(recursive: true);
      }

      if (mounted) {
        setState(() {
          modelInfo.status = ModelDownloadStatus.notDownloaded;
          modelInfo.downloadedBytes = 0;
          modelInfo.totalBytes = null;
          modelInfo.errorMessage = null;
          modelInfo.statusMessage = null; // Clear status message on delete
          modelInfo.hasCompressedFile =
              false; // Clear compressed file flag on delete
        });
        // Re-check if all models are downloaded after deletion
        _checkAllDownloaded();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          modelInfo.errorMessage = 'Failed to delete: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      showLogo: true,
      topPadding: 10,
      bodyWidget: _isInitializing
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: CircularProgressIndicator(),
              ),
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final maxHeight = MediaQuery.of(context).size.height * 0.8;
                return ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Scrollbar(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8.0),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Horizontal step indicators
                            _buildHorizontalStepIndicator(),

                            // Step content
                            _currentStep == 0
                                ? _buildStep1Content()
                                : _buildStep2Content(),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
