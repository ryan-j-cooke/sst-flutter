import 'package:flutter/material.dart';
import 'package:stttest/utils/sherpa-onxx-sst.dart';

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
                            ? Icons.folder_zip
                            : Icons.download,
                        size: 24,
                      ),
                      onPressed: isDownloaded ? null : onDownload,
                      color: isDownloaded ? Colors.grey[400] : Colors.blue[700],
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
