import 'package:flutter/material.dart';
import 'package:stttest/utils/sherpa-onxx-sst.dart';

/// Model download status
enum ModelDownloadStatus { notDownloaded, downloading, downloaded, error }

/// Model info with download status
class ModelInfo {
  final SherpaModelType model;
  final String displayName;
  final String fileSize;
  ModelDownloadStatus status;
  int downloadedBytes;
  int? totalBytes;
  String? errorMessage;
  String? statusMessage; // Current status message (e.g., "Extracting...", "Decompressing...")
  bool hasCompressedFile; // Whether the .tar.bz2 file exists but model files don't

  ModelInfo({
    required this.model,
    required this.displayName,
    required this.fileSize,
    this.status = ModelDownloadStatus.notDownloaded,
    this.downloadedBytes = 0,
    this.totalBytes,
    this.errorMessage,
    this.statusMessage,
    this.hasCompressedFile = false,
  });
}

/// Download List Item Widget
class DownloadListItem extends StatelessWidget {
  final ModelInfo modelInfo;
  final String fileSizeText;
  final bool isRequired;
  final VoidCallback? onDownload;
  final VoidCallback? onCancel;
  final VoidCallback? onDelete;

  const DownloadListItem({
    super.key,
    required this.modelInfo,
    required this.fileSizeText,
    this.isRequired = false,
    this.onDownload,
    this.onCancel,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isDownloaded = modelInfo.status == ModelDownloadStatus.downloaded;
    final isDownloading = modelInfo.status == ModelDownloadStatus.downloading;
    final hasError = modelInfo.status == ModelDownloadStatus.error;

    return Container(
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
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      // Status message (for extraction progress, etc.)
                      if (modelInfo.statusMessage != null &&
                          modelInfo.statusMessage!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          modelInfo.statusMessage!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDownloading
                                ? Colors.blue[700]
                                : Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
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
                    onPressed: onDownload,
                    color: Colors.blue[700],
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip: modelInfo.hasCompressedFile
                        ? 'Extract model'
                        : 'Download model',
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
    );
  }
}
