import 'dart:async';
import 'dart:io';

import '../cards/index.dart';
import '../../../utils/sherpa-onxx-sst.dart';
import '../../../utils/file.dart';
import './download-list-item.dart';
import './step-1.dart';
import './step-2.dart';
import 'package:flutter/material.dart';

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
  final Map<SherpaModelType, ModelInfo> _modelInfos = {};
  final Map<SherpaModelType, CancellationToken> _cancelTokens = {};
  bool _isInitializing = true;
  bool _isDownloadingAll = false;
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _initializeModels();
  }

  Future<void> _initializeModels() async {
    setState(() {
      _isInitializing = true;
    });

    // Initialize model infos
    for (final model in widget.requiredModels) {
      final displayName = model.displayName;
      final fileSize = model.fileSize;
      final exists = await SherpaOnnxSTTHelper.modelExists(model);

      _modelInfos[model] = ModelInfo(
        model: model,
        displayName: displayName,
        fileSize: fileSize,
        status: exists
            ? ModelDownloadStatus.downloaded
            : ModelDownloadStatus.notDownloaded,
      );
    }

    setState(() {
      _isInitializing = false;
    });

    // Check if all models are already downloaded
    _checkAllDownloaded();
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

  /// Check if required models are downloaded (required for step 2)
  /// For Sherpa-ONNX, we check if at least one model is downloaded
  bool _areRequiredModelsDownloaded() {
    // Check if at least the first required model is downloaded
    if (widget.requiredModels.isEmpty) return false;
    final firstModelInfo = _modelInfos[widget.requiredModels.first];
    return firstModelInfo?.status == ModelDownloadStatus.downloaded;
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
      return;
    }

    // Create cancellation token for this download
    final cancelToken = CancellationToken();
    _cancelTokens[modelInfo.model] = cancelToken;

    setState(() {
      modelInfo.status = ModelDownloadStatus.downloading;
      modelInfo.downloadedBytes = 0;
      modelInfo.totalBytes = null;
      modelInfo.errorMessage = null;
    });

    try {
      final modelDir = await SherpaOnnxSTTHelper.getModelPath(modelInfo.model);
      await Directory(modelDir).create(recursive: true);

      await SherpaOnnxSTTHelper.downloadModel(
        modelInfo.model,
        modelDir,
        onProgress: (downloaded, total) {
          if (mounted && !cancelToken.isCancelled) {
            setState(() {
              modelInfo.downloadedBytes = downloaded;
              modelInfo.totalBytes = total;
            });
          }
        },
        cancelToken: cancelToken,
      );

      if (mounted && !cancelToken.isCancelled) {
        setState(() {
          modelInfo.status = ModelDownloadStatus.downloaded;
        });
        _checkAllDownloaded();
      }
    } catch (e) {
      if (mounted) {
        if (e.toString().contains('cancelled')) {
          setState(() {
            modelInfo.status = ModelDownloadStatus.notDownloaded;
            modelInfo.downloadedBytes = 0;
            modelInfo.totalBytes = null;
            modelInfo.errorMessage = null;
          });
        } else {
          setState(() {
            modelInfo.status = ModelDownloadStatus.error;
            modelInfo.errorMessage = e.toString();
          });
        }
      }
    } finally {
      _cancelTokens.remove(modelInfo.model);
    }
  }

  /// Cancel a model download
  void _cancelDownload(ModelInfo modelInfo) {
    final cancelToken = _cancelTokens[modelInfo.model];
    if (cancelToken != null) {
      cancelToken.cancel();
      setState(() {
        modelInfo.status = ModelDownloadStatus.notDownloaded;
        modelInfo.downloadedBytes = 0;
        modelInfo.totalBytes = null;
        modelInfo.errorMessage = null;
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
      });
    }

    // Download all models in parallel
    final downloadFutures = modelsToDownload.map((modelInfo) async {
      // Create cancellation token for this download
      final cancelToken = CancellationToken();
      _cancelTokens[modelInfo.model] = cancelToken;

      try {
        final modelDir = await SherpaOnnxSTTHelper.getModelPath(
          modelInfo.model,
        );
        await Directory(modelDir).create(recursive: true);

        await SherpaOnnxSTTHelper.downloadModel(
          modelInfo.model,
          modelDir,
          onProgress: (downloaded, total) {
            if (mounted && !cancelToken.isCancelled) {
              setState(() {
                modelInfo.downloadedBytes = downloaded;
                modelInfo.totalBytes = total;
              });
            }
          },
          cancelToken: cancelToken,
        );

        if (mounted && !cancelToken.isCancelled) {
          setState(() {
            modelInfo.status = ModelDownloadStatus.downloaded;
          });
        }
      } catch (e) {
        if (mounted) {
          if (e.toString().contains('cancelled')) {
            setState(() {
              modelInfo.status = ModelDownloadStatus.notDownloaded;
              modelInfo.downloadedBytes = 0;
              modelInfo.totalBytes = null;
              modelInfo.errorMessage = null;
            });
          } else {
            setState(() {
              modelInfo.status = ModelDownloadStatus.error;
              modelInfo.errorMessage = e.toString();
            });
          }
        }
      } finally {
        _cancelTokens.remove(modelInfo.model);
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
    );
  }

  Widget _buildStep2Content() {
    return Step2Content(
      canProceed: _areRequiredModelsDownloaded(),
      languageCode: widget.languageCode ?? 'en',
      availableModels: widget.requiredModels,
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
      final modelDir = await SherpaOnnxSTTHelper.getModelPath(modelInfo.model);
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
