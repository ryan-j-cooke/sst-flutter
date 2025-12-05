import '../typeography/h3.dart';
import '../page.dart';
import 'package:flutter/material.dart';
import 'package:stttest/utils/sherpa-model-dictionary.dart';
import 'package:stttest/apps/services/tutor/tutor.service.dart';

/// Step 2 Content Widget
///
/// Displays model selection list and footer with save button.
class Step2Content extends StatefulWidget {
  final bool canProceed;
  final String languageCode;
  final List<SherpaModelVariant> availableModels; // Changed to support both enum and custom
  final VoidCallback? onSaveComplete;

  const Step2Content({
    super.key,
    required this.canProceed,
    required this.languageCode,
    required this.availableModels,
    this.onSaveComplete,
  });

  @override
  State<Step2Content> createState() => _Step2ContentState();
}

class _Step2ContentState extends State<Step2Content> {
  SherpaModelVariant? _selectedModel;
  bool _isLoading = true;
  bool _isSaving = false;
  bool _isSaved = false;

  @override
  void initState() {
    super.initState();
    _loadSavedModel();
  }

  /// Load the saved model priority for this language
  Future<void> _loadSavedModel() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get saved model name (works for both enum and custom models)
      final savedModelName = await TutorService.getModelPriorityName(
        widget.languageCode,
      );

      if (mounted) {
        setState(() {
          // Check if we have any available models
          if (widget.availableModels.isEmpty) {
            _selectedModel = null;
            _isLoading = false;
            return;
          }

          // Find the saved model by comparing modelName
          if (savedModelName != null) {
            _selectedModel = widget.availableModels.firstWhere(
              (variant) => variant.modelName == savedModelName,
              orElse: () => widget.availableModels.first,
            );
          } else {
            _selectedModel = widget.availableModels.first;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          // Default to first available on error, or null if list is empty
          _selectedModel = widget.availableModels.isNotEmpty
              ? widget.availableModels.first
              : null;
          _isLoading = false;
        });
      }
    }
  }

  /// Save the selected model priority
  Future<void> _saveModelPriority() async {
    if (_selectedModel == null || _isSaving || _isSaved) return;

    setState(() {
      _isSaving = true;
    });

    try {
      // Persist the model priority setting using TutorService
      // Support both enum and custom models
      final success = await TutorService.saveModelPriority(
        widget.languageCode,
        _selectedModel!.model, // Enum model (null for custom)
        modelName: _selectedModel!.modelName, // Always provide model name
      );

      if (success && mounted) {
        // Show tick icon
        setState(() {
          _isSaving = false;
          _isSaved = true;
        });

        // Wait a moment to show the tick, then trigger transition
        await Future.delayed(const Duration(milliseconds: 800));

        if (mounted) {
          // Trigger the callback to start transition
          widget.onSaveComplete?.call();
        }
      } else {
        // Show error if save failed
        if (mounted) {
          setState(() {
            _isSaving = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to save settings'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      // Handle any errors during save
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Select a model (without saving yet)
  void _selectModel(SherpaModelVariant model) {
    setState(() {
      _selectedModel = model;
    });
  }

  void _showModelInfo(BuildContext context, SherpaModelVariant model) {
    // Select the model when info icon is clicked
    _selectModel(model);

    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => _ModelInfoPage(
          selectedModel: model,
          availableModels: widget.availableModels,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          // Create a fancy transform animation with overflow protection
          final curvedAnimation = CurvedAnimation(
            parent: animation,
            curve: Curves.easeInOutCubic,
          );

          return ClipRect(
            clipBehavior: Clip.antiAlias,
            child: RotationTransition(
              turns: curvedAnimation.drive(Tween(begin: -0.1, end: 0.0)),
              child: ScaleTransition(
                scale: curvedAnimation.drive(Tween(begin: 0.8, end: 1.0)),
                child: SlideTransition(
                  position: curvedAnimation.drive(
                    Tween(begin: const Offset(0.0, 0.1), end: Offset.zero),
                  ),
                  child: FadeTransition(opacity: curvedAnimation, child: child),
                ),
              ),
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.canProceed) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange[200]!),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange[700]),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Please download at least one model to continue.',
                style: TextStyle(color: Colors.orange[700], fontSize: 14),
              ),
            ),
          ],
        ),
      );
    }


    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Title
        H3(
          text: 'Select Model',
          type: 'dark',
          align: TextAlign.center,
          marginTop: 25,
          marginBottom: 8,
        ),
        // Message
        Padding(
          padding: const EdgeInsets.only(bottom: 16.0),
          child: Text(
            'Choose a Sherpa-ONNX model for speech-to-text. Larger models provide better accuracy but require more storage.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.5,
            ),
            textAlign: TextAlign.left,
          ),
        ),
        const SizedBox(height: 16),

        // Model selection list
        if (_isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          )
        else
          ...widget.availableModels.map((variant) {
            final isSelected = _selectedModel == variant;
            final displayName = variant.displayName;
            final fileSize = variant.fileSize;

            return Container(
              margin: const EdgeInsets.only(bottom: 6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blue[50] : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.blue[300]! : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _selectModel(variant),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        // Radio button
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isSelected
                                  ? Colors.blue[700]!
                                  : Colors.grey[400]!,
                              width: 2,
                            ),
                            color: isSelected
                                ? Colors.blue[700]
                                : Colors.transparent,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                        const SizedBox(width: 16),
                        // Model info
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: isSelected
                                      ? Colors.blue[700]
                                      : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                fileSize,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Info icon at far right
                        GestureDetector(
                          onTap: () => _showModelInfo(context, variant),
                          behavior: HitTestBehavior.opaque,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Icon(
                              Icons.info_outline,
                              size: 20,
                              color: Colors.blue[700],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

        // Footer with Save button
        Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: ElevatedButton(
            onPressed: (_selectedModel != null && !_isSaving && !_isSaved)
                ? _saveModelPriority
                : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              backgroundColor: _isSaved ? Colors.green[700] : Colors.green[700],
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[400],
              disabledForegroundColor: Colors.grey[600],
            ),
            child: _isSaving
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : _isSaved
                ? const Icon(Icons.check, size: 24)
                : const Text('Save', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }
}

/// Model Info Page
///
/// Displays detailed information about available models with the same transition
/// animation as the store course details page.
class _ModelInfoPage extends StatelessWidget {
  final List<SherpaModelVariant> availableModels;
  final SherpaModelVariant? selectedModel;

  const _ModelInfoPage({
    required this.selectedModel,
    required this.availableModels,
  });

  @override
  Widget build(BuildContext context) {
    return AppPage(
      routeName: 'model-info',
      headerTitle: 'Model Information',
      showBackButton: true,
      headerTransparent: false,
      padding: 20,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ...availableModels.map((variant) {
              final isSelected = variant == selectedModel;
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.teal[50] : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.teal[300]! : Colors.grey[300]!,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      variant.displayName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.teal[900] : Colors.grey[800],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Size: ${variant.fileSize}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isSelected ? Colors.teal[700] : Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Model: ${variant.modelName}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isSelected ? Colors.teal[600] : Colors.grey[500],
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
