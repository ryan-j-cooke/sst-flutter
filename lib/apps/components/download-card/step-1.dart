import '../typeography/h3.dart';
import './download-list-item.dart';
import 'package:flutter/material.dart';
import 'package:stttest/utils/sherpa-onxx-sst.dart';

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
  });

  @override
  Widget build(BuildContext context) {
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
            'Download the required Sherpa-ONNX models to enable speech-to-text functionality.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.left,
          ),
        ),
        const SizedBox(height: 16),

        ...modelInfos.values.map((modelInfo) {
          return DownloadListItem(
            modelInfo: modelInfo,
            fileSizeText: getFileSizeText(modelInfo),
            isRequired:
                modelInfo == modelInfos.values.first, // First model is required
            onDownload: () => onDownloadModel(modelInfo),
            onCancel: () => onCancelDownload(modelInfo),
            onDelete: () => onDeleteModel(modelInfo),
          );
        }),
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
