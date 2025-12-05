import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:stttest/utils/sherpa-onxx-sst.dart';

// Calculate similarity using Levenshtein distance (exact copy from study.dart)
int calculateSimilarity(String transcribed, String expected) {
  if (transcribed.isEmpty && expected.isEmpty) return 100;
  if (transcribed.isEmpty || expected.isEmpty) return 0;

  // Convert to lower case for case-insensitive comparison
  transcribed = transcribed.toLowerCase();
  expected = expected.toLowerCase();

  // Initialize a 2D array for Levenshtein distance
  List<List<int>> dp = List.generate(
    transcribed.length + 1,
    (_) => List.filled(expected.length + 1, 0),
  );

  for (int i = 0; i <= transcribed.length; i++) dp[i][0] = i;
  for (int j = 0; j <= expected.length; j++) dp[0][j] = j;

  for (int i = 1; i <= transcribed.length; i++) {
    for (int j = 1; j <= expected.length; j++) {
      if (transcribed[i - 1] == expected[j - 1]) {
        dp[i][j] = dp[i - 1][j - 1];
      } else {
        dp[i][j] =
            1 +
            [
              dp[i - 1][j], // deletion
              dp[i][j - 1], // insertion
              dp[i - 1][j - 1], // substitution
            ].reduce((a, b) => a < b ? a : b);
      }
    }
  }

  int distance = dp[transcribed.length][expected.length];
  int maxLength = expected.length > transcribed.length
      ? expected.length
      : transcribed.length;

  double similarity = ((maxLength - distance) / maxLength) * 100;

  return similarity.round();
}

/// Sherpa-ONNX STT (Speech-to-Text) Button Component
///
/// A button with gradient styling, animations, press/hold logic, and Sherpa-ONNX-based STT.
class SherpaOnnxSTTButton extends StatefulWidget {
  final String languageCode;
  final String? expectedText;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onReleased;
  final String? label;
  final bool expanded;
  final Function(String transcribedText, int percentage)?
  onSpeechTranscribed; // Deprecated: Use onResult and onTranscriptionCompleted
  final Function(String partialText)?
  onResult; // Called for partial results during transcription
  final Function(String transcribedText, int percentage)?
  onTranscriptionCompleted; // Called when transcription is complete
  final Function(bool state)? onStateChanged;
  final SherpaModelType? sherpaModel;
  final String? customModelName;

  const SherpaOnnxSTTButton({
    Key? key,
    required this.languageCode,
    this.expectedText,
    this.onTap,
    this.onLongPress,
    this.onReleased,
    this.label,
    this.expanded = false,
    this.onSpeechTranscribed,
    this.onResult,
    this.onTranscriptionCompleted,
    this.onStateChanged,
    this.sherpaModel,
    this.customModelName,
  }) : super(key: key);

  @override
  State<SherpaOnnxSTTButton> createState() => _SherpaOnnxSTTButtonState();
}

class _SherpaOnnxSTTButtonState extends State<SherpaOnnxSTTButton>
    with SingleTickerProviderStateMixin {
  final AudioRecorder _audioRecorder = AudioRecorder();
  OfflineRecognizer? _recognizer;
  String? _currentRecordingPath;

  bool doingAction = false;
  bool _isPressed = false;
  bool _isLongPress = false;
  bool _isInitializing = false;
  bool _isRecording = false;
  bool _isTranscribing = false;
  Timer? _tapTimer;
  Timer? _recordingTimer;

  late AnimationController _buttonController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    print('[sherpa-onnx-btn] initState: Initializing button');
    print(
      '[sherpa-onnx-btn] initState: sherpaModel=${widget.sherpaModel?.displayName ?? "null"} (${widget.sherpaModel?.modelName ?? widget.customModelName ?? "none"})',
    );
    print('[sherpa-onnx-btn] initState: languageCode=${widget.languageCode}');
    print(
      '[sherpa-onnx-btn] initState: customModelName=${widget.customModelName}',
    );
    _buttonController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _buttonController, curve: Curves.easeInOut),
    );
    _initializeSherpa();
  }

  @override
  void didUpdateWidget(SherpaOnnxSTTButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    print('[sherpa-onnx-btn] didUpdateWidget: Widget updated');
    print(
      '[sherpa-onnx-btn] didUpdateWidget: Old model=${oldWidget.sherpaModel?.displayName ?? oldWidget.customModelName ?? "null"}, New model=${widget.sherpaModel?.displayName ?? widget.customModelName ?? "null"}',
    );
    print(
      '[sherpa-onnx-btn] didUpdateWidget: Old languageCode=${oldWidget.languageCode}, New languageCode=${widget.languageCode}',
    );

    // Re-initialize if model or language changed
    if (oldWidget.sherpaModel != widget.sherpaModel ||
        oldWidget.customModelName != widget.customModelName ||
        oldWidget.languageCode != widget.languageCode) {
      print(
        '[sherpa-onnx-btn] didUpdateWidget: Model or language changed, re-initializing...',
      );
      _recognizer = null; // Clear old recognizer
      _initializeSherpa();
    }
  }

  @override
  void dispose() {
    print('[sherpa-onnx-btn] dispose: Disposing button');
    _tapTimer?.cancel();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _recognizer = null;
    _buttonController.dispose();
    super.dispose();
  }

  //-----------------------------------------------------
  // SHERPA-ONNX INITIALIZATION
  //-----------------------------------------------------
  Future<void> _initializeSherpa() async {
    print('[sherpa-onnx-btn] _initializeSherpa: Starting initialization');
    print(
      '[sherpa-onnx-btn] _initializeSherpa: _isInitializing=$_isInitializing',
    );
    print(
      '[sherpa-onnx-btn] _initializeSherpa: widget.sherpaModel=${widget.sherpaModel?.displayName ?? "null"} (${widget.sherpaModel?.modelName ?? widget.customModelName ?? "none"})',
    );
    print(
      '[sherpa-onnx-btn] _initializeSherpa: widget.languageCode=${widget.languageCode}',
    );
    print(
      '[sherpa-onnx-btn] _initializeSherpa: widget.customModelName=${widget.customModelName}',
    );

    if (_isInitializing) {
      print(
        '[sherpa-onnx-btn] _initializeSherpa: Already initializing, skipping',
      );
      return;
    }

    setState(() {
      _isInitializing = true;
    });

    // Yield control multiple times to ensure loading indicator is shown and UI updates
    await Future.delayed(const Duration(milliseconds: 100));
    await Future.microtask(() {});
    await Future.delayed(Duration.zero);
    await Future.microtask(() {});

    try {
      // Initialize recognizer using helper
      print(
        '[sherpa-onnx-btn] _initializeSherpa: Calling SherpaOnnxSTTHelper.initializeRecognizer...',
      );
      if (widget.sherpaModel != null) {
        _recognizer = await SherpaOnnxSTTHelper.initializeRecognizer(
          widget.sherpaModel!,
        );
      } else if (widget.customModelName != null) {
        _recognizer = await SherpaOnnxSTTHelper.initializeRecognizerByName(
          widget.customModelName!,
        );
      } else {
        throw Exception(
          'No model provided (neither sherpaModel nor customModelName)',
        );
      }
      print(
        '[sherpa-onnx-btn] _initializeSherpa: Recognizer initialized successfully',
      );

      setState(() {
        _isInitializing = false;
      });
      print('[sherpa-onnx-btn] _initializeSherpa: Initialization complete');
    } catch (e, stackTrace) {
      print('[sherpa-onnx-btn] _initializeSherpa: ERROR - $e');
      print('[sherpa-onnx-btn] _initializeSherpa: Stack trace: $stackTrace');
      setState(() {
        _isInitializing = false;
      });
      debugPrint('Error initializing Sherpa-ONNX: $e');
    }
  }

  //-----------------------------------------------------
  // BUTTON STATE MANAGEMENT
  //-----------------------------------------------------
  void _updateDoingAction(bool value) {
    if (doingAction != value) {
      setState(() {
        doingAction = value;
      });
      widget.onStateChanged?.call(value);

      // Start or stop recording
      if (value) {
        _startRecording();
      } else {
        _stopRecording();
      }
    }
  }

  /// Ensure recognizer is initialized before proceeding
  Future<bool> _ensureRecognizerInitialized() async {
    if (_recognizer != null) {
      return true;
    }

    if (_isInitializing) {
      print(
        '[sherpa-onnx-btn] _ensureRecognizerInitialized: Recognizer is initializing, waiting...',
      );
      // Wait for initialization to complete (with timeout)
      int attempts = 0;
      const maxAttempts = 100; // 10 seconds max wait
      while (_isInitializing && attempts < maxAttempts) {
        await Future.delayed(const Duration(milliseconds: 100));
        attempts++;
        if (_recognizer != null) {
          print(
            '[sherpa-onnx-btn] _ensureRecognizerInitialized: Recognizer initialized after waiting',
          );
          return true;
        }
      }
      print(
        '[sherpa-onnx-btn] _ensureRecognizerInitialized: Timeout waiting for initialization',
      );
      return false;
    }

    // Not initializing and recognizer is null, try to initialize
    print(
      '[sherpa-onnx-btn] _ensureRecognizerInitialized: Recognizer is null, attempting initialization...',
    );
    try {
      await _initializeSherpa();
      return _recognizer != null;
    } catch (e) {
      print(
        '[sherpa-onnx-btn] _ensureRecognizerInitialized: ERROR - Failed to initialize: $e',
      );
      return false;
    }
  }

  //-----------------------------------------------------
  // BUTTON PRESS LOGIC
  //-----------------------------------------------------
  void _handlePressStart() {
    setState(() {
      _isPressed = true;
      _isLongPress = false;
    });

    _buttonController.forward();
    _tapTimer?.cancel();
  }

  void _handlePressEnd() {
    _tapTimer?.cancel();

    setState(() {
      _isPressed = false;
      if (_isLongPress) _updateDoingAction(false);
    });
    _buttonController.reverse();

    if (_isLongPress) {
      widget.onReleased?.call();
    }
    _isLongPress = false;
  }

  void _handleTapDown() {
    if (!_isLongPress) {
      _updateDoingAction(!doingAction);
      widget.onTap?.call();
    }
  }

  void _handleLongPress() {
    setState(() {
      _isLongPress = true;
    });
    _updateDoingAction(true);
    widget.onLongPress?.call();
  }

  //-----------------------------------------------------
  // RECORDING LOGIC
  //-----------------------------------------------------
  Future<void> _startRecording() async {
    // Ensure recognizer is initialized before starting recording
    final isReady = await _ensureRecognizerInitialized();
    if (!isReady) {
      print(
        '[sherpa-onnx-btn] _startRecording: ERROR - Recognizer not initialized, cannot start recording',
      );
      setState(() {
        doingAction = false;
      });
      widget.onStateChanged?.call(false);
      return;
    }
    if (_isRecording || _isInitializing) return;

    try {
      // Play system beep when recording starts
      SystemSound.play(SystemSoundType.click);

      // Check permissions
      if (await _audioRecorder.hasPermission() == false) {
        setState(() {
          doingAction = false;
        });
        widget.onStateChanged?.call(false);
        return;
      }

      // Get temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/recording_$timestamp.wav';

      // Start recording
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );

      setState(() {
        _isRecording = true;
      });

      // Start timer for recording (can be used for UI updates if needed)
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        // Timer can be used for UI updates if needed
      });
    } catch (e) {
      setState(() {
        _isRecording = false;
        doingAction = false;
      });
      widget.onStateChanged?.call(false);
      debugPrint('Error starting recording: $e');
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    try {
      _recordingTimer?.cancel();
      _recordingTimer = null;

      // Stop recording
      final path = await _audioRecorder.stop();
      if (path != null) {
        _currentRecordingPath = path;
      }

      setState(() {
        _isRecording = false;
      });

      // Play system beep when recording ends
      SystemSound.play(SystemSoundType.click);

      // Ensure recognizer is initialized before transcribing
      final isReady = await _ensureRecognizerInitialized();
      if (!isReady) {
        print(
          '[sherpa-onnx-btn] _stopRecording: ERROR - Recognizer not initialized, cannot transcribe',
        );
        setState(() {
          doingAction = false;
        });
        widget.onStateChanged?.call(false);
        return;
      }

      // Automatically transcribe after stopping
      await _transcribeAudio();
    } catch (e) {
      setState(() {
        _isRecording = false;
        doingAction = false;
      });
      widget.onStateChanged?.call(false);
      debugPrint('Error stopping recording: $e');
    }
  }

  //-----------------------------------------------------
  // TRANSCRIPTION LOGIC
  //-----------------------------------------------------
  Future<void> _transcribeAudio() async {
    print('[sherpa-onnx-btn] _transcribeAudio: Starting transcription');
    print(
      '[sherpa-onnx-btn] _transcribeAudio: _recognizer=${_recognizer != null ? "initialized" : "null"}',
    );
    print(
      '[sherpa-onnx-btn] _transcribeAudio: _currentRecordingPath=$_currentRecordingPath',
    );

    if (_recognizer == null || _currentRecordingPath == null) {
      print(
        '[sherpa-onnx-btn] _transcribeAudio: ERROR - Recognizer or recording path is null',
      );
      setState(() {
        doingAction = false;
      });
      widget.onStateChanged?.call(false);
      return;
    }

    // Check if recording file exists
    final audioFile = File(_currentRecordingPath!);
    final fileExists = await audioFile.exists();
    print('[sherpa-onnx-btn] _transcribeAudio: Audio file exists=$fileExists');
    if (!fileExists) {
      print(
        '[sherpa-onnx-btn] _transcribeAudio: ERROR - Audio file does not exist',
      );
      setState(() {
        doingAction = false;
      });
      widget.onStateChanged?.call(false);
      return;
    }

    // Update UI state immediately to show processing
    setState(() {
      _isTranscribing = true;
    });

    // Yield control to UI thread to ensure state update is rendered
    await Future.delayed(Duration.zero);

    try {
      // Transcribe using helper with partial result callback for real-time updates
      // Note: Recognizer operations must stay in main isolate, but we'll yield control periodically
      print(
        '[sherpa-onnx-btn] _transcribeAudio: Calling SherpaOnnxSTTHelper.transcribeAudio with partial results...',
      );

      // Run transcription in a way that yields control periodically
      final transcribedText = await _transcribeAudioWithYields(
        audioPath: _currentRecordingPath!,
        onPartialResult: (partialText) {
          // Call callback with partial result in real-time
          print(
            '[sherpa-onnx-btn] _transcribeAudio: Partial result received: "$partialText"',
          );
          if (mounted) {
            // Call onResult callback for partial results
            widget.onResult?.call(partialText);
            // Also call deprecated onSpeechTranscribed for backward compatibility
            widget.onSpeechTranscribed?.call(partialText, 0);
          }
        },
      );

      print(
        '[sherpa-onnx-btn] _transcribeAudio: Final transcription result: "$transcribedText"',
      );

      // Calculate similarity in an isolate to avoid blocking UI
      int percentage = 0;
      if (widget.expectedText != null && transcribedText.isNotEmpty) {
        print(
          '[sherpa-onnx-btn] _transcribeAudio: Calculating similarity in isolate...',
        );
        percentage = await _calculateSimilarityInIsolate(
          transcribedText,
          widget.expectedText!,
        );
        print(
          '[sherpa-onnx-btn] _transcribeAudio: Similarity percentage: $percentage%',
        );
      }

      // Call the callback with final transcribed text and percentage
      if (transcribedText.isNotEmpty) {
        print(
          '[sherpa-onnx-btn] _transcribeAudio: Calling onTranscriptionCompleted callback with final result',
        );
        // Call onTranscriptionCompleted callback for final results
        widget.onTranscriptionCompleted?.call(transcribedText, percentage);
        // Also call deprecated onSpeechTranscribed for backward compatibility
        widget.onSpeechTranscribed?.call(transcribedText, percentage);
      } else {
        print(
          '[sherpa-onnx-btn] _transcribeAudio: WARNING - Transcribed text is empty',
        );
      }

      setState(() {
        _isTranscribing = false;
        doingAction = false;
      });
      widget.onStateChanged?.call(false);
      print('[sherpa-onnx-btn] _transcribeAudio: Transcription complete');
    } catch (e, stackTrace) {
      print('[sherpa-onnx-btn] _transcribeAudio: ERROR - $e');
      print('[sherpa-onnx-btn] _transcribeAudio: Stack trace: $stackTrace');
      setState(() {
        _isTranscribing = false;
        doingAction = false;
      });
      widget.onStateChanged?.call(false);
      debugPrint('Error transcribing: $e');
    }
  }

  /// Transcribe audio with periodic yields to keep UI responsive
  /// Since OfflineRecognizer can't be passed to isolates, yielding happens in transcribeAudio
  Future<String> _transcribeAudioWithYields({
    required String audioPath,
    Function(String)? onPartialResult,
  }) async {
    // Yield control before starting transcription to ensure UI state is updated
    await Future.delayed(Duration.zero);

    // Call transcription - it will yield control periodically internally
    return await SherpaOnnxSTTHelper.transcribeAudio(
      recognizer: _recognizer!,
      audioPath: audioPath,
      onPartialResult: (partialText) {
        // Call callback - UI updates will happen on next frame
        onPartialResult?.call(partialText);
      },
    );
  }

  /// Calculate similarity in an isolate to avoid blocking UI
  Future<int> _calculateSimilarityInIsolate(
    String transcribed,
    String expected,
  ) async {
    final receivePort = ReceivePort();

    await Isolate.spawn(_calculateSimilarityIsolate, {
      'sendPort': receivePort.sendPort,
      'transcribed': transcribed,
      'expected': expected,
    });

    final result = await receivePort.first as int;
    return result;
  }

  /// Isolate entry point for similarity calculation
  static void _calculateSimilarityIsolate(Map<String, dynamic> message) {
    final sendPort = message['sendPort'] as SendPort;
    final transcribed = message['transcribed'] as String;
    final expected = message['expected'] as String;

    try {
      final percentage = calculateSimilarity(transcribed, expected);
      sendPort.send(percentage);
    } catch (e) {
      sendPort.send(0);
    }
  }

  //-----------------------------------------------------
  // BUILD WIDGET
  //-----------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final isLoading = _isInitializing || _isTranscribing;
    final isActive = doingAction || _isRecording || _isTranscribing;

    final label = widget.label ?? 'Press to speak';

    final button = AnimatedBuilder(
      animation: _scaleAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isPressed ? _scaleAnimation.value : 1.0,
          child: Listener(
            onPointerDown: (_) => _handlePressStart(),
            onPointerUp: (_) => _handlePressEnd(),
            onPointerCancel: (_) => _handlePressEnd(),
            child: GestureDetector(
              onTapDown: (_) => _handleTapDown(),
              onLongPress: _handleLongPress,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 52,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isActive
                        ? [const Color(0xFFFF4D4F), const Color(0xFFFF6B6B)]
                        : [const Color(0xFF1677FF), const Color(0xFF3B82F6)],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color:
                          (isActive
                                  ? const Color(0xFFFF4D4F)
                                  : const Color(0xFF1677FF))
                              .withValues(alpha: isActive ? 0.5 : 0.3),
                      blurRadius: isActive ? 12 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (isLoading)
                      const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    else
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.mic_rounded,
                          key: ValueKey(isActive),
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (isActive && !isLoading) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );

    if (widget.expanded) return Expanded(child: button);

    return button;
  }
}
