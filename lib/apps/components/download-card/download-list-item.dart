import 'package:flutter/material.dart';
import 'package:stttest/utils/sherpa-onxx-sst.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Model download status
enum ModelDownloadStatus { notDownloaded, downloading, downloaded, error }

/// Model info with download status
class ModelInfo {
  final SherpaModelType? model; // Null for custom models
  final String? customModelName; // Used for custom models
  final String displayName;
  final String fileSize;
  ModelDownloadStatus status;
  int downloadedBytes;
  int? totalBytes;
  String? errorMessage;
  String?
  statusMessage; // Current status message (e.g., "Extracting...", "Decompressing...")
  bool
  hasCompressedFile; // Whether the .tar.bz2 file exists but model files don't

  ModelInfo({
    this.model,
    this.customModelName,
    required this.displayName,
    required this.fileSize,
    this.status = ModelDownloadStatus.notDownloaded,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.errorMessage,
    this.statusMessage,
    this.hasCompressedFile = false,
  }) : assert(
         model != null || customModelName != null,
         'Either model or customModelName must be provided',
       );

  /// Get the model name for downloads/checks
  String get modelName => model?.modelName ?? customModelName!;
}

/// Download List Item Widget
class DownloadListItem extends StatelessWidget {
  final ModelInfo modelInfo;
  final String fileSizeText;
  final bool isRequired;
  final VoidCallback? onDownload;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;
  final VoidCallback? onRefreshStatus; // Callback to refresh model status

  const DownloadListItem({
    super.key,
    required this.modelInfo,
    required this.fileSizeText,
    this.isRequired = false,
    this.onDownload,
    this.onCancel,
    this.onDelete,
    this.onRefreshStatus,
  });

  /// Build status message widget with different styles based on process type
  Widget _buildStatusMessage(
    String statusMessage,
    bool isDownloading,
    bool hasError,
    String? errorMessage,
  ) {
    // Check if we're in extraction/decompression phase (unzipping)
    final isUnzipping =
        statusMessage.toLowerCase().contains('extracting') ||
        statusMessage.toLowerCase().contains('decompressing') ||
        statusMessage.toLowerCase().contains('decoding') ||
        statusMessage.toLowerCase().contains('decompressed') ||
        statusMessage.toLowerCase().contains('decoded') ||
        statusMessage.toLowerCase().contains('reading archive');

    // Check if we're in other processing phases (not download, not unzip)
    final isOtherProcess =
        !isDownloading && !isUnzipping && statusMessage.isNotEmpty;

    if (isUnzipping) {
      // Parse the status message to extract filename and progress
      String? fileName;
      String progressText = statusMessage;

      // Try to extract filename from status message
      // Format: "Extracting files... (1/12)\nfilename.onnx"
      if (statusMessage.contains('\n')) {
        final parts = statusMessage.split('\n');
        if (parts.length > 1) {
          progressText = parts[0];
          fileName = parts[1];
        }
      }

      // Extract progress percentage if available
      // Format: "Extracting files... (1/12)" or "Decompressing bzip2..."
      String displayProgress = progressText;
      if (progressText.contains('(') && progressText.contains(')')) {
        final match = RegExp(r'\((\d+)/(\d+)\)').firstMatch(progressText);
        if (match != null) {
          final current = match.group(1);
          final total = match.group(2);
          if (current != null && total != null) {
            final percent = (int.parse(current) / int.parse(total) * 100)
                .round();
            displayProgress = progressText.replaceAll(
              '($current/$total)',
              '$percent%',
            );
          }
        }
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (fileName != null) ...[
            Text(
              fileName,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.blue,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
          ],
          Text(
            displayProgress,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.blue,
              fontStyle: FontStyle.italic,
            ),
          ),
          if (hasError && errorMessage != null) ...[
            const SizedBox(height: 4),
            Text(
              'Error: $errorMessage',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      );
    } else if (isOtherProcess) {
      // Other processes (not download, not unzip) - use orange color
      return Text(
        statusMessage,
        style: const TextStyle(
          fontSize: 11,
          color: Colors.orange,
          fontStyle: FontStyle.italic,
        ),
      );
    } else if (hasError && errorMessage != null) {
      // Error state
      return Text(
        'Error: $errorMessage',
        style: const TextStyle(
          fontSize: 11,
          color: Colors.red,
          fontWeight: FontWeight.w500,
        ),
      );
    } else {
      // Default: downloading - keep current blue color
      return Text(
        statusMessage,
        style: TextStyle(
          fontSize: 11,
          color: Colors.blue[700],
          fontStyle: FontStyle.italic,
        ),
      );
    }
  }

  /// Show dialog with manual action options
  void _showManualActionsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Manual Actions: ${modelInfo.displayName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showDownloadDialog(context);
              },
              icon: const Icon(Icons.download),
              label: const Text('Download Model'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showExtractDialog(context);
              },
              icon: const Icon(Icons.unarchive),
              label: const Text('Extract Model'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showVerifyDialog(context);
              },
              icon: const Icon(Icons.verified),
              label: const Text('Verify Model'),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _showInitializeDialog(context);
              },
              icon: const Icon(Icons.play_arrow),
              label: const Text('Initialize Model'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  /// Show download progress dialog
  Future<void> _showDownloadDialog(BuildContext context) async {
    print(
      '[download-list-item] _showDownloadDialog: Starting download dialog for ${modelInfo.displayName}',
    );

    // Store setState function and state variables to use in callbacks
    void Function(VoidCallback)? dialogSetState;
    final output = <String>[];
    bool isComplete = false;
    String? error;
    int downloadedBytes = 0;
    int? totalBytes;
    double extractionProgress = 0.0;
    String? extractionStatus;
    bool isDownloading = false;
    bool isExtracting = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          // Capture setState for use in async callbacks
          dialogSetState = setState;

          return AlertDialog(
            title: Text('Downloading: ${modelInfo.displayName}'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isComplete &&
                      error == null &&
                      !isDownloading &&
                      !isExtracting)
                    const CircularProgressIndicator(),
                  if (error != null)
                    Text(
                      'Error: $error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  if (isComplete && error == null) ...[
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 48,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Download and extraction complete!',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Download progress
                  if (isDownloading && totalBytes != null) ...[
                    LinearProgressIndicator(
                      value: downloadedBytes / totalBytes!,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${(downloadedBytes / 1024 / 1024).toStringAsFixed(2)} MB / ${(totalBytes! / 1024 / 1024).toStringAsFixed(2)} MB (${(downloadedBytes / totalBytes! * 100).toStringAsFixed(1)}%)',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  // Extraction progress
                  if (isExtracting) ...[
                    LinearProgressIndicator(
                      value: extractionProgress / 100.0,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      extractionStatus ?? 'Extracting...',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.orange,
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    height: 200,
                    child: SingleChildScrollView(
                      child: Text(
                        output.isEmpty
                            ? 'Starting download...'
                            : output.join('\n'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isComplete || error != null
                    ? () => Navigator.pop(dialogContext)
                    : null,
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );

    try {
      print('[download-list-item] _showDownloadDialog: Getting directories');
      final documentsDir = await getApplicationDocumentsDirectory();
      final modelDir =
          '${documentsDir.path}/sherpa_onnx_models/${modelInfo.modelName}';

      print(
        '[download-list-item] _showDownloadDialog: Model directory: $modelDir',
      );
      await Directory(modelDir).create(recursive: true);

      print('[download-list-item] _showDownloadDialog: Starting download...');
      await SherpaOnnxSTTHelper.downloadModelByName(
        modelInfo.modelName,
        modelDir,
        displayName: modelInfo.displayName,
        onProgress: (downloaded, total) {
          print(
            '[download-list-item] _showDownloadDialog: onProgress callback - downloaded: $downloaded, total: $total, progress: ${total != null ? ((downloaded / total) * 100).toStringAsFixed(1) : "?"}%',
          );
          if (context.mounted && dialogSetState != null) {
            final percent = total != null
                ? (downloaded / total * 100).toStringAsFixed(1)
                : '?';
            final percentValue = total != null
                ? (downloaded / total * 100)
                : 0.0;
            print(
              '[download-list-item] _showDownloadDialog: Percentage calculation: ($downloaded / ${total ?? "null"}) * 100 = $percentValue%',
            );
            final logMsg =
                'Downloaded: ${(downloaded / 1024 / 1024).toStringAsFixed(2)} MB / ${total != null ? (total / 1024 / 1024).toStringAsFixed(2) : "?"} MB ($percent%)';
            print('[download-list-item] _showDownloadDialog: $logMsg');

            dialogSetState!(() {
              downloadedBytes = downloaded;
              totalBytes = total;
              isDownloading = true;
              isExtracting = false;
              output.add(logMsg);
            });
          }
        },
        onExtractionProgress: (progress, status) {
          print(
            '[download-list-item] _showDownloadDialog: onExtractionProgress callback - progress: $progress, status: $status',
          );
          if (context.mounted && dialogSetState != null) {
            final logMsg =
                'Extraction: ${progress.toStringAsFixed(1)}% - $status';
            print('[download-list-item] _showDownloadDialog: $logMsg');

            dialogSetState!(() {
              isDownloading = false;
              isExtracting = true;
              extractionProgress = progress;
              extractionStatus = status;
              output.add(logMsg);
            });
          }
        },
      );

      if (context.mounted && dialogSetState != null) {
        print(
          '[download-list-item] _showDownloadDialog: Download and extraction complete',
        );
        dialogSetState!(() {
          isDownloading = false;
          isExtracting = false;
          isComplete = true;
          output.add('✓ Download and extraction complete!');
        });
        onRefreshStatus?.call();
      }
    } catch (e) {
      print('[download-list-item] _showDownloadDialog: Error occurred: $e');
      if (context.mounted && dialogSetState != null) {
        dialogSetState!(() {
          isDownloading = false;
          isExtracting = false;
          error = e.toString();
          output.add('✗ Error: $e');
        });
      }
    }
  }

  /// Show extract progress dialog
  Future<void> _showExtractDialog(BuildContext context) async {
    final output = <String>[];
    bool isComplete = false;
    String? error;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Extracting: ${modelInfo.displayName}'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isComplete && error == null)
                    const CircularProgressIndicator(),
                  if (error != null)
                    Text(
                      'Error: $error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  if (isComplete && error == null)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 48,
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: SingleChildScrollView(
                      child: Text(
                        output.isEmpty
                            ? 'Starting extraction...'
                            : output.join('\n'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isComplete || error != null
                    ? () => Navigator.pop(context)
                    : null,
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );

    try {
      final tempDir = await getTemporaryDirectory();
      final zipFile = File('${tempDir.path}/${modelInfo.modelName}.tar.bz2');
      final documentsDir = await getApplicationDocumentsDirectory();
      final modelDir =
          '${documentsDir.path}/sherpa_onnx_models/${modelInfo.modelName}';

      if (!await zipFile.exists()) {
        throw Exception('Compressed file not found: ${zipFile.path}');
      }

      output.add('Found compressed file: ${zipFile.path}');
      if (context.mounted) (context as Element).markNeedsBuild();

      await Directory(modelDir).create(recursive: true);

      // Use downloadModelByName which handles extraction
      await SherpaOnnxSTTHelper.downloadModelByName(
        modelInfo.modelName,
        modelDir,
        displayName: modelInfo.displayName,
        onExtractionProgress: (progress, status) {
          if (context.mounted) {
            output.add('$status (${progress.toStringAsFixed(1)}%)');
            (context as Element).markNeedsBuild();
          }
        },
      );

      if (context.mounted) {
        output.add('✓ Extraction complete!');
        isComplete = true;
        (context as Element).markNeedsBuild();
        onRefreshStatus?.call();
      }
    } catch (e) {
      if (context.mounted) {
        error = e.toString();
        output.add('✗ Error: $e');
        (context as Element).markNeedsBuild();
      }
    }
  }

  /// Show verify dialog
  Future<void> _showVerifyDialog(BuildContext context) async {
    final output = <String>[];
    bool isComplete = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Verifying: ${modelInfo.displayName}'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isComplete) const CircularProgressIndicator(),
                  if (isComplete)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 48,
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: SingleChildScrollView(
                      child: Text(
                        output.isEmpty
                            ? 'Verifying model files...'
                            : output.join('\n'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isComplete ? () => Navigator.pop(context) : null,
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );

    try {
      output.add('Checking model: ${modelInfo.modelName}');
      if (context.mounted) (context as Element).markNeedsBuild();

      await SherpaOnnxSTTHelper.debugModel(
        modelInfo.modelName,
        displayName: modelInfo.displayName,
      );

      final exists = await SherpaOnnxSTTHelper.modelExistsByName(
        modelInfo.modelName,
      );

      if (context.mounted) {
        output.add('Model exists: $exists');
        if (exists) {
          output.add('✓ All required files are present');
        } else {
          output.add('✗ Model files are missing');
        }
        isComplete = true;
        (context as Element).markNeedsBuild();
      }
    } catch (e) {
      if (context.mounted) {
        output.add('✗ Error: $e');
        isComplete = true;
        (context as Element).markNeedsBuild();
      }
    }
  }

  /// Show initialize dialog
  Future<void> _showInitializeDialog(BuildContext context) async {
    final output = <String>[];
    bool isComplete = false;
    String? error;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Initializing: ${modelInfo.displayName}'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isComplete && error == null)
                    const CircularProgressIndicator(),
                  if (error != null)
                    Text(
                      'Error: $error',
                      style: const TextStyle(color: Colors.red),
                    ),
                  if (isComplete && error == null)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                      size: 48,
                    ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 200,
                    child: SingleChildScrollView(
                      child: Text(
                        output.isEmpty
                            ? 'Initializing recognizer...'
                            : output.join('\n'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: isComplete || error != null
                    ? () => Navigator.pop(context)
                    : null,
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );

    try {
      output.add('Initializing model: ${modelInfo.modelName}');
      if (context.mounted) (context as Element).markNeedsBuild();

      await SherpaOnnxSTTHelper.initializeRecognizerByName(
        modelInfo.modelName,
        displayName: modelInfo.displayName,
      );

      if (context.mounted) {
        output.add('✓ Recognizer initialized successfully');
        output.add('Model is ready for transcription');
        isComplete = true;
        (context as Element).markNeedsBuild();
      }
    } catch (e) {
      if (context.mounted) {
        error = e.toString();
        output.add('✗ Error: $e');
        (context as Element).markNeedsBuild();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDownloaded = modelInfo.status == ModelDownloadStatus.downloaded;
    final isDownloading = modelInfo.status == ModelDownloadStatus.downloading;
    final hasError = modelInfo.status == ModelDownloadStatus.error;

    return GestureDetector(
      onTap: () async {
        // Call debug method on tap
        await SherpaOnnxSTTHelper.debugModel(
          modelInfo.modelName,
          displayName: modelInfo.displayName,
        );

        // After debug, check if model exists and refresh status if needed
        final modelExists = await SherpaOnnxSTTHelper.modelExistsByName(
          modelInfo.modelName,
        );

        // If model exists but status is not downloaded, refresh status
        if (modelExists && modelInfo.status != ModelDownloadStatus.downloaded) {
          onRefreshStatus?.call();
        }
      },
      onLongPress: () {
        _showManualActionsDialog(context);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(16, 8, 0, 8),
        decoration: BoxDecoration(
          color: isDownloaded
              ? Colors.green[50]
              : hasError
              ? Colors.red[50]
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDownloaded
                ? Colors.green[200]!
                : hasError
                ? Colors.red[200]!
                : Colors.grey[300]!,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // WRAPPED ROW FIX ▶️ Icons now align to the far right
            SizedBox(
              width: double.infinity,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // LEFT SIDE TEXT
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                modelInfo.displayName,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isRequired) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange[100],
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: Colors.orange[300]!,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  'Required',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.orange[800],
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          fileSizeText,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                        // Status message (for extraction progress, etc.)
                        if (modelInfo.statusMessage != null &&
                            modelInfo.statusMessage!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          _buildStatusMessage(
                            modelInfo.statusMessage!,
                            isDownloading,
                            hasError,
                            modelInfo.errorMessage,
                          ),
                        ],
                      ],
                    ),
                  ),

                  // RIGHT SIDE ICONS
                  if (isDownloaded)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Transform.translate(
                          offset: const Offset(8, 0),
                          child: Icon(
                            Icons.check_circle,
                            color: Colors.green[700],
                            size: 24,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline, size: 20),
                          onPressed: onDelete,
                          color: Colors.red[700],
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    )
                  else if (hasError)
                    Icon(Icons.error, color: Colors.red[700], size: 24)
                  else if (isDownloading)
                    Stack(
                      alignment: Alignment.center,
                      children: [
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        IconButton(
                          icon: const Icon(Icons.stop, size: 16),
                          onPressed: onCancel,
                          color: Colors.red[700],
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    )
                  else
                    IconButton(
                      icon: Icon(
                        modelInfo.hasCompressedFile
                            ? Icons.unarchive
                            : Icons.download,
                        size: 24,
                      ),
                      onPressed: isDownloaded ? null : onDownload,
                      color: isDownloaded
                          ? Colors.grey[400]
                          : (modelInfo.hasCompressedFile
                                ? Colors.orange[700]
                                : Colors.blue[700]),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 32,
                        minHeight: 32,
                      ),
                      tooltip: isDownloaded
                          ? 'Model already downloaded'
                          : (modelInfo.hasCompressedFile
                                ? 'Extract model'
                                : 'Download model'),
                    ),
                ],
              ),
            ),

            // ERROR MESSAGE
            if (hasError && modelInfo.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                'Error: ${modelInfo.errorMessage}',
                style: TextStyle(fontSize: 12, color: Colors.red[700]),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
