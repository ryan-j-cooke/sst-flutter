import '../typeography/h3.dart';
import './download-list-item.dart';
import 'package:flutter/material.dart';

/// Step 1 Content Widget
///
/// Displays the model download list and footer buttons.
class Step1Content extends StatelessWidget {
  final Map<String, ModelInfo> modelInfos;
  final bool isDownloadingAll;
  final bool areAllModelsDownloaded;
  final bool areAllModelsDownloadingOrDownloaded;
  final bool canProgressToStep2;
  final String Function(ModelInfo) getFileSizeText;
  final VoidCallback onDownloadAll;
  final VoidCallback onProgressToStep2;
  final Function(ModelInfo) onDownloadModel;
  final Function(ModelInfo) onCancelDownload;
  final Function(ModelInfo) onDeleteModel;
  final Function(ModelInfo)? onRefreshStatus;

  const Step1Content({
    super.key,
    required this.modelInfos,
    required this.isDownloadingAll,
    required this.areAllModelsDownloaded,
    required this.areAllModelsDownloadingOrDownloaded,
    required this.canProgressToStep2,
    required this.getFileSizeText,
    required this.onDownloadAll,
    required this.onProgressToStep2,
    required this.onDownloadModel,
    required this.onCancelDownload,
    required this.onDeleteModel,
    this.onRefreshStatus,
  });

  @override
  Widget build(BuildContext context) {
    // Sort models: downloaded (or has compressed file) first, then others
    final sortedModels = modelInfos.values.toList()
      ..sort((a, b) {
        // Check if model is downloaded or has compressed file
        final aIsDownloaded =
            a.status == ModelDownloadStatus.downloaded || a.hasCompressedFile;
        final bIsDownloaded =
            b.status == ModelDownloadStatus.downloaded || b.hasCompressedFile;

        // Downloaded models come first
        if (aIsDownloaded && !bIsDownloaded) return -1;
        if (!aIsDownloaded && bIsDownloaded) return 1;

        // If both have same status, maintain original order (by display name)
        return a.displayName.compareTo(b.displayName);
      });

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title
        H3(
          text: 'Download Models',
          type: 'dark',
          align: TextAlign.center,
          marginTop: 25,
          marginBottom: 8,
        ),
        // Message
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            'Download and extract at least one Sherpa-ONNX model to enable speech-to-text functionality.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.left,
          ),
        ),
        const SizedBox(height: 16),

        // Scrollable models list with auto height (up to max)
        LayoutBuilder(
          builder: (context, constraints) {
            // Calculate max height (25% of screen height, clamped between 200-400px)
            final screenHeight = MediaQuery.of(context).size.height;
            final maxListHeight = (screenHeight * 0.25).clamp(200.0, 400.0);

            // Estimate height per item (approximately 80px per item including margins)
            const estimatedItemHeight = 80.0;
            final estimatedTotalHeight =
                sortedModels.length * estimatedItemHeight;

            // Determine if scrolling is needed
            final needsScrolling = estimatedTotalHeight > maxListHeight;

            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: maxListHeight,
                minHeight: 0,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: needsScrolling
                    ? const AlwaysScrollableScrollPhysics()
                    : const NeverScrollableScrollPhysics(),
                itemCount: sortedModels.length,
                separatorBuilder: (context, index) => const SizedBox(height: 0),
                itemBuilder: (context, index) {
                  final modelInfo = sortedModels[index];
                  return DownloadListItem(
                    modelInfo: modelInfo,
                    fileSizeText: getFileSizeText(modelInfo),
                    onDownload: () => onDownloadModel(modelInfo),
                    onCancel: () => onCancelDownload(modelInfo),
                    onDelete: () => onDeleteModel(modelInfo),
                    onRefreshStatus: onRefreshStatus != null
                        ? () => onRefreshStatus!(modelInfo)
                        : null,
                  );
                },
              ),
            );
          },
        ),
        // Footer with Download All and Next buttons
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Row(
            children: [
              // Download All button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed:
                      (!areAllModelsDownloaded &&
                          !isDownloadingAll &&
                          modelInfos.values.any(
                            (info) =>
                                info.status != ModelDownloadStatus.downloaded,
                          ) &&
                          !areAllModelsDownloadingOrDownloaded)
                      ? onDownloadAll
                      : null,
                  icon: const Icon(Icons.cloud_download, size: 20),
                  label: const Text('All', style: TextStyle(fontSize: 16)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    backgroundColor: Colors.blue[700],
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[400],
                    disabledForegroundColor: Colors.grey[600],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Next button
              Expanded(
                child: ElevatedButton(
                  onPressed: canProgressToStep2 ? onProgressToStep2 : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    backgroundColor: Colors.green[700],
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[400],
                    disabledForegroundColor: Colors.grey[600],
                  ),
                  child: const Text('Next', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
