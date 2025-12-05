import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:stttest/utils/file.dart'
    show FileDownloadHelper, CancellationToken;

// Sherpa-ONNX model types
enum SherpaModelType {
  zipformerEn('Zipformer EN', 'sherpa-onnx-zipformer-en-2023-06-26', '~293 MB'),
  zipformerTh(
    'Zipformer TH',
    'sherpa-onnx-zipformer-thai-2024-06-20',
    '~663 MB',
  ),
  zipformerZh(
    'Zipformer ZH',
    'sherpa-onnx-zipformer-zh-en-2023-11-22',
    '~298 MB',
  ),
  paraformerZh(
    'Paraformer ZH',
    'sherpa-onnx-paraformer-zh-2024-03-09',
    '~950 MB',
  ),
  zipformerRu('Zipformer RU', 'sherpa-onnx-zipformer-ru-2024-09-18', '~284 MB'),
  zipformerKo(
    'Zipformer KO',
    'sherpa-onnx-zipformer-korean-2024-06-24',
    '~314 MB',
  ),
  whisperTiny('Whisper Tiny', 'sherpa-onnx-whisper-tiny', '~111 MB'),
  whisperBase('Whisper Base', 'sherpa-onnx-whisper-base', '~198 MB'),
  whisperSmall('Whisper Small', 'sherpa-onnx-whisper-small', '~610 MB');

  final String displayName;
  final String modelName;
  final String fileSize;

  const SherpaModelType(this.displayName, this.modelName, this.fileSize);
}

// Language codes for Sherpa-ONNX
class Language {
  final String name;
  final String code;

  const Language(this.name, this.code);
}

// Isolate function for background extraction
// Optimized to reduce memory usage by processing in steps and clearing references
Future<void> _extractModelInIsolate(Map<String, dynamic> params) async {
  final sendPort = params['sendPort'] as SendPort;
  List<int>? tarBz2Bytes;
  List<int>? tarBytes;
  Archive? archive;
  
  try {
    final tarBz2Path = params['tarBz2Path'] as String;
    final modelDir = params['modelDir'] as String;
    final modelName = params['modelName'] as String;

    sendPort.send({'status': 'reading', 'progress': 0.0});

    // Read the tar.bz2 file in chunks to reduce peak memory
    final tarBz2File = File(tarBz2Path);
    final fileSize = await tarBz2File.length();
    
    // For very large files, warn about memory usage
    if (fileSize > 500 * 1024 * 1024) { // > 500MB
      sendPort.send({
        'status': 'warning',
        'message': 'Large file detected (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB). Extraction may use significant memory.',
      });
    }

    // Read file - this is still necessary for bzip2 decompression
    tarBz2Bytes = await tarBz2File.readAsBytes();
    sendPort.send({
      'status': 'read',
      'progress': 10.0,
      'size': tarBz2Bytes.length,
    });

    // Decompress bzip2
    sendPort.send({'status': 'decompressing', 'progress': 15.0});
    final bz2Decoder = BZip2Decoder();
    tarBytes = bz2Decoder.decodeBytes(tarBz2Bytes);
    
    // Clear compressed bytes from memory immediately after decompression
    tarBz2Bytes = null;
    
    // Force garbage collection hint (Dart VM will handle this)
    // Note: Dart doesn't have explicit GC, but clearing references helps
    
    sendPort.send({
      'status': 'decompressed',
      'progress': 40.0,
      'size': tarBytes.length,
    });

    // Extract tar archive
    sendPort.send({'status': 'decoding', 'progress': 45.0});
    final tarDecoder = TarDecoder();
    archive = tarDecoder.decodeBytes(tarBytes);
    
    // Clear tar bytes from memory after decoding
    tarBytes = null;
    
    sendPort.send({
      'status': 'decoded',
      'progress': 50.0,
      'fileCount': archive.files.length,
    });

    // Extract all files one at a time, clearing file content after writing
    int fileCount = 0;
    final fileList = archive.files.where((f) => f.isFile).toList();
    final totalFiles = fileList.length;

    for (final file in fileList) {
      fileCount++;
      final filename = file.name;

      // Calculate progress (50-100%)
      final progress = 50.0 + (fileCount / totalFiles) * 50.0;
      sendPort.send({
        'status': 'extracting',
        'progress': progress,
        'fileCount': fileCount,
        'totalFiles': totalFiles,
        'currentFile': filename,
      });

      // Handle nested paths in the archive
      final pathParts = filename.split('/');
      // Find the model name directory and skip it
      String relativePath = filename;
      for (int i = 0; i < pathParts.length; i++) {
        if (pathParts[i] == modelName || pathParts[i].startsWith(modelName)) {
          if (i + 1 < pathParts.length) {
            relativePath = pathParts.sublist(i + 1).join('/');
          } else {
            // If the model name is the last part, use just the filename
            relativePath = pathParts.last;
          }
          break;
        }
      }

      // If no model name found, try to use the path after the first directory
      if (relativePath == filename && pathParts.length > 1) {
        relativePath = pathParts.sublist(1).join('/');
      }

      final outputFile = File('$modelDir/$relativePath');
      try {
        await outputFile.parent.create(recursive: true);
        
        // Write file content
        final content = file.content;
        if (content is List<int>) {
          await outputFile.writeAsBytes(content);
        } else if (content is Uint8List) {
          await outputFile.writeAsBytes(content);
        }
        
        // Clear file content reference after writing (help GC)
        // Note: file.content is still in memory in the archive, but we've written it
      } catch (e) {
        sendPort.send({'error': 'Failed to extract $filename: $e'});
      }
    }

    // Clear archive reference
    archive = null;

    sendPort.send({
      'status': 'completed',
      'progress': 100.0,
      'fileCount': fileCount,
    });
  } catch (e, stackTrace) {
    // Clear all references on error
    tarBz2Bytes = null;
    tarBytes = null;
    archive = null;
    
    sendPort.send({
      'error': 'Extraction failed: $e',
      'stackTrace': stackTrace.toString(),
    });
  }
}

/// Sherpa-ONNX STT Helper
///
/// Provides static methods for model management, initialization, and transcription
class SherpaOnnxSTTHelper {
  /// Check if a model exists locally (using enum)
  static Future<bool> modelExists(SherpaModelType model) async {
    return modelExistsByName(model.modelName);
  }

  /// Check if a model exists locally (using model name string)
  static Future<bool> modelExistsByName(String modelName) async {
    try {
      print('[sherpa-onxx-sst] modelExistsByName: Checking model=$modelName');
      final documentsDir = await getApplicationDocumentsDirectory();
      final modelDir =
          '${documentsDir.path}/sherpa_onnx_models/$modelName';
      print('[sherpa-onxx-sst] modelExistsByName: Model directory=$modelDir');

      final encoderFile = File('$modelDir/encoder.onnx');
      final decoderFile = File('$modelDir/decoder.onnx');
      final joinerFile = File('$modelDir/joiner.onnx');
      final tokensFile = File('$modelDir/tokens.txt');

      final encoderExists = await encoderFile.exists();
      final decoderExists = await decoderFile.exists();
      final joinerExists = await joinerFile.exists();
      final tokensExists = await tokensFile.exists();
      
      print('[sherpa-onxx-sst] modelExistsByName: encoderExists=$encoderExists');
      print('[sherpa-onxx-sst] modelExistsByName: decoderExists=$decoderExists');
      print('[sherpa-onxx-sst] modelExistsByName: joinerExists=$joinerExists');
      print('[sherpa-onxx-sst] modelExistsByName: tokensExists=$tokensExists');
      
      final allExist = encoderExists && decoderExists && joinerExists && tokensExists;
      print('[sherpa-onxx-sst] modelExistsByName: Result=$allExist');
      return allExist;
    } catch (e) {
      print('[sherpa-onxx-sst] modelExistsByName: ERROR - $e');
      return false;
    }
  }

  /// Ensure model exists, downloading and extracting if necessary
  ///
  /// Returns the model directory path
  static Future<String> ensureModelExists(SherpaModelType model) async {
    print('[sherpa-onxx-sst] ensureModelExists: Starting for model=${model.displayName} (${model.modelName})');
    // Get model directory
    final documentsDir = await getApplicationDocumentsDirectory();
    final modelDir =
        '${documentsDir.path}/sherpa_onnx_models/${model.modelName}';
    print('[sherpa-onxx-sst] ensureModelExists: Model directory=$modelDir');
    await Directory(modelDir).create(recursive: true);

    // Check if model files already exist
    final encoderFile = File('$modelDir/encoder.onnx');
    final decoderFile = File('$modelDir/decoder.onnx');
    final joinerFile = File('$modelDir/joiner.onnx');
    final tokensFile = File('$modelDir/tokens.txt');

    final encoderExists = await encoderFile.exists();
    final decoderExists = await decoderFile.exists();
    final joinerExists = await joinerFile.exists();
    final tokensExists = await tokensFile.exists();
    
    final modelExists = encoderExists && decoderExists && joinerExists && tokensExists;
    print('[sherpa-onxx-sst] ensureModelExists: Model files exist=$modelExists');
    print('[sherpa-onxx-sst] ensureModelExists: encoderExists=$encoderExists, decoderExists=$decoderExists, joinerExists=$joinerExists, tokensExists=$tokensExists');

    if (!modelExists) {
      // Model doesn't exist, check if downloaded file exists
      final tempDir = await getTemporaryDirectory();
      final downloadedFile = File('${tempDir.path}/${model.modelName}.tar.bz2');

      if (await downloadedFile.exists()) {
        // Check file size against remote
        try {
          final localSize = await downloadedFile.length();
          final remoteSize = await _getRemoteFileSize(
            'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/${model.modelName}.tar.bz2',
          );

          if (remoteSize != null && localSize == remoteSize) {
            // File exists and size matches, extract it
            await _extractModel(downloadedFile, modelDir, model.modelName);
          } else {
            // Size doesn't match, re-download
            await downloadedFile.delete();
            await _downloadModel(model);
            final redownloadedFile = File(
              '${tempDir.path}/${model.modelName}.tar.bz2',
            );
            await _extractModel(redownloadedFile, modelDir, model.modelName);
          }
        } catch (e) {
          // If we can't check, re-download to be safe
          if (await downloadedFile.exists()) {
            await downloadedFile.delete();
          }
          await _downloadModel(model);
          final redownloadedFile = File(
            '${tempDir.path}/${model.modelName}.tar.bz2',
          );
          await _extractModel(redownloadedFile, modelDir, model.modelName);
        }
      } else {
        // No downloaded file, download it
        await _downloadModel(model);
        final tempDir = await getTemporaryDirectory();
        final downloadedFile = File(
          '${tempDir.path}/${model.modelName}.tar.bz2',
        );
        await _extractModel(downloadedFile, modelDir, model.modelName);
      }
    }

    return modelDir;
  }

  /// Initialize Sherpa-ONNX recognizer
  ///
  /// Returns the initialized OfflineRecognizer
  /// This method performs file checks in an isolate to avoid blocking the UI
  static Future<OfflineRecognizer> initializeRecognizer(
    SherpaModelType model,
  ) async {
    print('[sherpa-onxx-sst] initializeRecognizer: Starting for model=${model.displayName} (${model.modelName})');
    
    // Ensure model exists (download/extract if needed) - this is already async
    final modelDir = await ensureModelExists(model);
    print('[sherpa-onxx-sst] initializeRecognizer: Model directory=$modelDir');

    // Initialize Sherpa-ONNX recognizer
    final encoderPath = '$modelDir/encoder.onnx';
    final decoderPath = '$modelDir/decoder.onnx';
    final joinerPath = '$modelDir/joiner.onnx';
    final tokensPath = '$modelDir/tokens.txt';

    print('[sherpa-onxx-sst] initializeRecognizer: Checking files...');
    print('[sherpa-onxx-sst] initializeRecognizer: encoderPath=$encoderPath');
    print('[sherpa-onxx-sst] initializeRecognizer: decoderPath=$decoderPath');
    print('[sherpa-onxx-sst] initializeRecognizer: joinerPath=$joinerPath');
    print('[sherpa-onxx-sst] initializeRecognizer: tokensPath=$tokensPath');

    // Perform file existence checks in an isolate to avoid blocking UI
    final fileCheckResult = await _checkModelFilesInIsolate(
      encoderPath,
      decoderPath,
      joinerPath,
      tokensPath,
    );
    
    print('[sherpa-onxx-sst] initializeRecognizer: encoderExists=${fileCheckResult['encoderExists']}');
    print('[sherpa-onxx-sst] initializeRecognizer: decoderExists=${fileCheckResult['decoderExists']}');
    print('[sherpa-onxx-sst] initializeRecognizer: joinerExists=${fileCheckResult['joinerExists']}');
    print('[sherpa-onxx-sst] initializeRecognizer: tokensExists=${fileCheckResult['tokensExists']}');

    if (!fileCheckResult['encoderExists']! || 
        !fileCheckResult['decoderExists']! || 
        !fileCheckResult['joinerExists']! || 
        !fileCheckResult['tokensExists']!) {
      print('[sherpa-onxx-sst] initializeRecognizer: ERROR - Model files missing!');
      throw Exception('Model files missing');
    }

    // Yield control to UI thread to allow loading indicator to show
    // Use a small delay to ensure UI has time to update
    await Future.delayed(const Duration(milliseconds: 50));
    
    print('[sherpa-onxx-sst] initializeRecognizer: All files exist, creating recognizer config...');
    // Initialize with transducer model config (for Zipformer models)
    final transducerConfig = OfflineTransducerModelConfig(
      encoder: encoderPath,
      decoder: decoderPath,
      joiner: joinerPath,
    );
    final modelConfig = OfflineModelConfig(
      transducer: transducerConfig,
      tokens: tokensPath,
    );
    final recognizerConfig = OfflineRecognizerConfig(
      model: modelConfig,
      feat: FeatureConfig(sampleRate: 16000),
    );

    // Yield control again before creating recognizer (this is the heavy operation)
    // This allows the UI to show the loading state before blocking
    await Future.delayed(const Duration(milliseconds: 50));
    
    print('[sherpa-onxx-sst] initializeRecognizer: Creating OfflineRecognizer...');
    // Note: OfflineRecognizer creation must happen on main thread (native object)
    // This is the blocking operation, but we've already shown loading state
    final recognizer = OfflineRecognizer(recognizerConfig);
    print('[sherpa-onxx-sst] initializeRecognizer: Recognizer created successfully');
    return recognizer;
  }

  /// Check model files existence in an isolate to avoid blocking UI
  static Future<Map<String, bool>> _checkModelFilesInIsolate(
    String encoderPath,
    String decoderPath,
    String joinerPath,
    String tokensPath,
  ) async {
    final receivePort = ReceivePort();
    
    await Isolate.spawn(_checkModelFilesIsolate, {
      'sendPort': receivePort.sendPort,
      'encoderPath': encoderPath,
      'decoderPath': decoderPath,
      'joinerPath': joinerPath,
      'tokensPath': tokensPath,
    });
    
    final result = await receivePort.first as Map<String, bool>;
    return result;
  }

  /// Isolate entry point for checking model files
  static void _checkModelFilesIsolate(Map<String, dynamic> message) {
    final sendPort = message['sendPort'] as SendPort;
    final encoderPath = message['encoderPath'] as String;
    final decoderPath = message['decoderPath'] as String;
    final joinerPath = message['joinerPath'] as String;
    final tokensPath = message['tokensPath'] as String;
    
    try {
      final encoderExists = File(encoderPath).existsSync();
      final decoderExists = File(decoderPath).existsSync();
      final joinerExists = File(joinerPath).existsSync();
      final tokensExists = File(tokensPath).existsSync();
      
      sendPort.send({
        'encoderExists': encoderExists,
        'decoderExists': decoderExists,
        'joinerExists': joinerExists,
        'tokensExists': tokensExists,
      });
    } catch (e) {
      // On error, return all false
      sendPort.send({
        'encoderExists': false,
        'decoderExists': false,
        'joinerExists': false,
        'tokensExists': false,
      });
    }
  }

  /// Transcribe audio file using Sherpa-ONNX
  ///
  /// [onPartialResult] - Optional callback for partial transcription results during processing
  /// Returns the final transcribed text
  static Future<String> transcribeAudio({
    required OfflineRecognizer recognizer,
    required String audioPath,
    Function(String partialText)? onPartialResult,
  }) async {
    print('[sherpa-onxx-sst] transcribeAudio: Starting transcription');
    print('[sherpa-onxx-sst] transcribeAudio: audioPath=$audioPath');
    print('[sherpa-onxx-sst] transcribeAudio: onPartialResult provided=${onPartialResult != null}');
    
    final audioFile = File(audioPath);
    if (!await audioFile.exists()) {
      throw Exception('Audio file not found: $audioPath');
    }

    // Create offline stream for transcription
    final stream = recognizer.createStream();
    print('[sherpa-onxx-sst] transcribeAudio: Stream created');

    try {
      // Read audio file and feed to recognizer
      final audioBytes = await audioFile.readAsBytes();
      print('[sherpa-onxx-sst] transcribeAudio: Audio file read, size=${audioBytes.length} bytes');

      // Process audio in chunks (16kHz, 16-bit, mono = 32000 bytes per second)
      // 100ms chunks = 3200 bytes per chunk
      const chunkSize = 3200; // 100ms chunks
      final totalChunks = (audioBytes.length / chunkSize).ceil();
      print('[sherpa-onxx-sst] transcribeAudio: Processing $totalChunks chunks');
      
      int chunkCount = 0;
      for (int i = 0; i < audioBytes.length; i += chunkSize) {
        final end = (i + chunkSize < audioBytes.length)
            ? i + chunkSize
            : audioBytes.length;
        final chunk = audioBytes.sublist(i, end);
        
        stream.acceptWaveform(
          samples: _bytesToSamples(chunk),
          sampleRate: 16000,
        );
        
        chunkCount++;
        
        // Get partial results periodically (every 10 chunks = ~1 second of audio)
        if (onPartialResult != null && chunkCount % 10 == 0) {
          try {
            recognizer.decode(stream);
            final partialResult = recognizer.getResult(stream);
            if (partialResult.text.isNotEmpty) {
              print('[sherpa-onxx-sst] transcribeAudio: Partial result: "${partialResult.text}"');
              onPartialResult(partialResult.text);
            }
          } catch (e) {
            // Ignore errors for partial results
            print('[sherpa-onxx-sst] transcribeAudio: Error getting partial result: $e');
          }
        }
      }

      print('[sherpa-onxx-sst] transcribeAudio: All chunks processed, getting final result...');
      // Input finished, decode and get final result
      recognizer.decode(stream);
      final result = recognizer.getResult(stream);
      final finalText = result.text.isNotEmpty ? result.text : '';
      print('[sherpa-onxx-sst] transcribeAudio: Final result: "$finalText"');
      return finalText;
    } finally {
      // Clean up stream
      print('[sherpa-onxx-sst] transcribeAudio: Cleaning up stream');
      stream.free();
    }
  }

  /// Convert bytes to float samples (16-bit PCM to float32)
  static Float32List _bytesToSamples(List<int> bytes) {
    final sampleCount = bytes.length ~/ 2;
    final samples = Float32List(sampleCount);
    for (int i = 0; i < bytes.length - 1; i += 2) {
      // Combine two bytes into a 16-bit signed integer
      final sample = (bytes[i] | (bytes[i + 1] << 8));
      // Convert to signed 16-bit
      final signedSample = sample > 32767 ? sample - 65536 : sample;
      // Normalize to [-1.0, 1.0]
      samples[i ~/ 2] = signedSample / 32768.0;
    }
    return samples;
  }

  /// Get the size of a remote file via HEAD request
  static Future<int?> _getRemoteFileSize(String url) async {
    try {
      final client = HttpClient();
      final request = await client.headUrl(Uri.parse(url));
      final response = await request.close();
      client.close();

      if (response.statusCode == 200) {
        final contentLength = response.contentLength;
        return contentLength > 0 ? contentLength : null;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Get model directory path for a given model
  static Future<String> getModelPath(SherpaModelType model) async {
    final documentsDir = await getApplicationDocumentsDirectory();
    return '${documentsDir.path}/sherpa_onnx_models/${model.modelName}';
  }

  /// Download model from GitHub releases with progress tracking and cancellation
  ///
  /// [onProgress] - Callback for download progress: (downloadedBytes, totalBytes)
  /// [onExtractionProgress] - Optional callback for extraction progress: (progress, status)
  ///   progress: 0.0 to 100.0, status: human-readable status string
  static Future<void> downloadModel(
    SherpaModelType model,
    String modelDir, {
    void Function(int downloaded, int? total)? onProgress,
    void Function(double progress, String status)? onExtractionProgress,
    CancellationToken? cancelToken,
  }) async {
    print('[sherpa-onxx-sst] downloadModel: ========== Starting download process ==========');
    print('[sherpa-onxx-sst] downloadModel: Model=${model.displayName} (${model.modelName})');
    print('[sherpa-onxx-sst] downloadModel: Model directory (destination for extracted files)=$modelDir');
    
    final modelUrl =
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/${model.modelName}.tar.bz2';
    print('[sherpa-onxx-sst] downloadModel: Model URL=$modelUrl');

    // First, check if model files already exist
    final encoderFile = File('$modelDir/encoder.onnx');
    final decoderFile = File('$modelDir/decoder.onnx');
    final joinerFile = File('$modelDir/joiner.onnx');
    final tokensFile = File('$modelDir/tokens.txt');

    print('[sherpa-onxx-sst] downloadModel: Checking model files existence...');
    print('[sherpa-onxx-sst] downloadModel: - encoder.onnx: ${encoderFile.path}');
    print('[sherpa-onxx-sst] downloadModel: - decoder.onnx: ${decoderFile.path}');
    print('[sherpa-onxx-sst] downloadModel: - joiner.onnx: ${joinerFile.path}');
    print('[sherpa-onxx-sst] downloadModel: - tokens.txt: ${tokensFile.path}');

    final encoderExists = await encoderFile.exists();
    final decoderExists = await decoderFile.exists();
    final joinerExists = await joinerFile.exists();
    final tokensExists = await tokensFile.exists();

    print('[sherpa-onxx-sst] downloadModel: File existence check results:');
    print('[sherpa-onxx-sst] downloadModel: - encoder.onnx exists: $encoderExists');
    print('[sherpa-onxx-sst] downloadModel: - decoder.onnx exists: $decoderExists');
    print('[sherpa-onxx-sst] downloadModel: - joiner.onnx exists: $joinerExists');
    print('[sherpa-onxx-sst] downloadModel: - tokens.txt exists: $tokensExists');

    final modelFilesExist = encoderExists &&
        decoderExists &&
        joinerExists &&
        tokensExists;

    if (modelFilesExist) {
      print('[sherpa-onxx-sst] downloadModel: ✓ All model files already exist, skipping download and extraction');
      print('[sherpa-onxx-sst] downloadModel: ========== Download process complete (no action needed) ==========');
      return;
    }

    // Model files don't exist, check if .tar.bz2 file exists
    final tempDir = await getTemporaryDirectory();
    final tempFilePath = '${tempDir.path}/${model.modelName}.tar.bz2';
    final downloadedFile = File(tempFilePath);

    print('[sherpa-onxx-sst] downloadModel: Model files missing, checking for compressed file...');
    print('[sherpa-onxx-sst] downloadModel: Compressed file location (destination for download)=$tempFilePath');

    final compressedFileExists = await downloadedFile.exists();
    print('[sherpa-onxx-sst] downloadModel: Compressed file (.tar.bz2) exists: $compressedFileExists');

    if (compressedFileExists) {
      final compressedFileSize = await downloadedFile.length();
      print('[sherpa-onxx-sst] downloadModel: Compressed file size: ${(compressedFileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      print('[sherpa-onxx-sst] downloadModel: Found existing .tar.bz2 file, verifying size...');
      
      // Verify file size matches remote (to ensure it's complete)
      try {
        final localSize = await downloadedFile.length();
        final remoteSize = await _getRemoteFileSize(modelUrl);
        
        if (remoteSize != null && localSize == remoteSize) {
          print('[sherpa-onxx-sst] downloadModel: ✓ Compressed file size matches remote (${(localSize / 1024 / 1024).toStringAsFixed(1)} MB)');
          print('[sherpa-onxx-sst] downloadModel: Skipping download, proceeding directly to extraction');
          print('[sherpa-onxx-sst] downloadModel: Extraction destination: $modelDir');
          // File exists and size matches, skip download and go straight to extraction
          await _extractModel(
            downloadedFile,
            modelDir,
            model.modelName,
            onProgress: onExtractionProgress,
          );
          print('[sherpa-onxx-sst] downloadModel: ========== Download process complete (extraction finished) ==========');
          return;
        } else {
          print('[sherpa-onxx-sst] downloadModel: ✗ Compressed file size mismatch (local: ${(localSize / 1024 / 1024).toStringAsFixed(2)} MB, remote: ${remoteSize != null ? (remoteSize / 1024 / 1024).toStringAsFixed(2) : "unknown"} MB)');
          print('[sherpa-onxx-sst] downloadModel: Deleting invalid compressed file and re-downloading...');
          // Size doesn't match, delete and re-download
          await downloadedFile.delete();
        }
      } catch (e) {
        print('[sherpa-onxx-sst] downloadModel: ✗ Error verifying existing file: $e');
        print('[sherpa-onxx-sst] downloadModel: Deleting compressed file and re-downloading...');
        // If we can't verify, delete and re-download to be safe
        if (await downloadedFile.exists()) {
          await downloadedFile.delete();
        }
      }
    }

    // .tar.bz2 file doesn't exist or was invalid, download it
    print('[sherpa-onxx-sst] downloadModel: Starting download from: $modelUrl');
    print('[sherpa-onxx-sst] downloadModel: Download destination: $tempFilePath');
    print('[sherpa-onxx-sst] downloadModel: Extraction will occur to: $modelDir');
    await FileDownloadHelper.downloadFile(
      Uri.parse(modelUrl),
      tempFilePath,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );

    // After download, extract the model
    if (await downloadedFile.exists()) {
      final downloadedSize = await downloadedFile.length();
      print('[sherpa-onxx-sst] downloadModel: ✓ Download complete, file size: ${(downloadedSize / 1024 / 1024).toStringAsFixed(2)} MB');
      print('[sherpa-onxx-sst] downloadModel: Starting extraction to: $modelDir');
      await _extractModel(
        downloadedFile,
        modelDir,
        model.modelName,
        onProgress: onExtractionProgress,
      );
      print('[sherpa-onxx-sst] downloadModel: ========== Download process complete (download + extraction finished) ==========');
    } else {
      print('[sherpa-onxx-sst] downloadModel: ✗ ERROR: Downloaded file does not exist after download');
      print('[sherpa-onxx-sst] downloadModel: ========== Download process failed ==========');
    }
  }

  /// Download model from GitHub releases (internal use)
  static Future<void> _downloadModel(SherpaModelType model) async {
    final modelUrl =
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/${model.modelName}.tar.bz2';

    // Download to temporary file first
    final tempDir = await getTemporaryDirectory();
    final tempFilePath = '${tempDir.path}/${model.modelName}.tar.bz2';

    // Use FileDownloadHelper for better error handling and progress tracking
    await FileDownloadHelper.downloadFile(Uri.parse(modelUrl), tempFilePath);
  }

  /// Extract model from tar.bz2 file
  ///
  /// [onProgress] - Optional callback for extraction progress: (progress, status)
  ///   progress: 0.0 to 100.0, status: human-readable status string
  static Future<void> _extractModel(
    File tarBz2File,
    String modelDir,
    String modelName, {
    void Function(double progress, String status)? onProgress,
  }) async {
    // First, check if model files already exist
    final encoderFile = File('$modelDir/encoder.onnx');
    final decoderFile = File('$modelDir/decoder.onnx');
    final joinerFile = File('$modelDir/joiner.onnx');
    final tokensFile = File('$modelDir/tokens.txt');

    // Check if all required files exist with expected names
    final allFilesExist =
        await encoderFile.exists() &&
        await decoderFile.exists() &&
        await joinerFile.exists() &&
        await tokensFile.exists();

    if (allFilesExist) {
      return;
    }

    // Check if files exist with different names (version-specific names)
    final foundFiles = await _findModelFiles(modelDir);

    if (foundFiles['encoder'] != null &&
        foundFiles['decoder'] != null &&
        foundFiles['joiner'] != null &&
        foundFiles['tokens'] != null) {
      // Copy files to expected names
      if (foundFiles['encoder'] != null && !await encoderFile.exists()) {
        await foundFiles['encoder']!.copy(encoderFile.path);
      }
      if (foundFiles['decoder'] != null && !await decoderFile.exists()) {
        await foundFiles['decoder']!.copy(decoderFile.path);
      }
      if (foundFiles['joiner'] != null && !await joinerFile.exists()) {
        await foundFiles['joiner']!.copy(joinerFile.path);
      }
      if (foundFiles['tokens'] != null && !await tokensFile.exists()) {
        await foundFiles['tokens']!.copy(tokensFile.path);
      }
      return;
    }

    // Files don't exist, proceed with extraction
    // Create a receive port to get progress updates from the isolate
    final receivePort = ReceivePort();

    // Spawn isolate for background extraction
    await Isolate.spawn(_extractModelInIsolate, {
      'sendPort': receivePort.sendPort,
      'tarBz2Path': tarBz2File.path,
      'modelDir': modelDir,
      'modelName': modelName,
    });

    // Listen for progress updates
    await for (final message in receivePort) {
      if (message is Map<String, dynamic>) {
        if (message.containsKey('error')) {
          throw Exception(message['error']);
        }

        final status = message['status'] as String?;
        final progress = (message['progress'] as num?)?.toDouble() ?? 0.0;
        final fileCount = message['fileCount'] as int?;
        final totalFiles = message['totalFiles'] as int?;
        final currentFile = message['currentFile'] as String?;

        // Build status text
        String statusText = '';
        switch (status) {
          case 'reading':
            statusText = 'Reading archive...';
            break;
          case 'read':
            final size = message['size'] as int?;
            if (size != null) {
              statusText = 'Read ${(size / 1024 / 1024).toStringAsFixed(1)} MB';
            }
            break;
          case 'decompressing':
            statusText = 'Decompressing bzip2...';
            break;
          case 'decompressed':
            final size = message['size'] as int?;
            if (size != null) {
              statusText =
                  'Decompressed ${(size / 1024 / 1024).toStringAsFixed(1)} MB';
            }
            break;
          case 'decoding':
            statusText = 'Decoding tar archive...';
            break;
          case 'decoded':
            statusText = 'Decoded ${message['fileCount']} files';
            break;
          case 'extracting':
            if (fileCount != null && totalFiles != null) {
              statusText = 'Extracting files... ($fileCount/$totalFiles)';
              if (currentFile != null) {
                final fileName = currentFile.split('/').last;
                statusText += '\n$fileName';
              }
            }
            break;
          case 'completed':
            statusText = 'Extraction complete! (${message['fileCount']} files)';
            break;
        }

        // Report progress if callback provided
        if (onProgress != null) {
          onProgress(progress, statusText);
        }

        if (status == 'completed') {
          break;
        }
      }
    }

    // Verify extracted files exist and find/rename them if needed
    await _verifyAndCopyModelFiles(modelDir);
  }

  /// Find model files in the model directory (recursively)
  static Future<Map<String, File?>> _findModelFiles(String modelDir) async {
    final foundFiles = <String, File?>{
      'encoder': null,
      'decoder': null,
      'joiner': null,
      'tokens': null,
    };

    final dir = Directory(modelDir);
    if (!await dir.exists()) {
      return foundFiles;
    }

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final name = entity.path.split('/').last.toLowerCase();

        // Find encoder (look for files starting with "encoder" and ending with ".onnx")
        // Prefer non-INT8 versions
        if (name.startsWith('encoder') && name.endsWith('.onnx')) {
          if (foundFiles['encoder'] == null) {
            foundFiles['encoder'] = entity;
          } else if (!name.contains('.int8') &&
              foundFiles['encoder']!.path.toLowerCase().contains('.int8')) {
            // Prefer non-INT8 version
            foundFiles['encoder'] = entity;
          }
        }
        // Find decoder
        if (name.startsWith('decoder') && name.endsWith('.onnx')) {
          if (foundFiles['decoder'] == null) {
            foundFiles['decoder'] = entity;
          } else if (!name.contains('.int8') &&
              foundFiles['decoder']!.path.toLowerCase().contains('.int8')) {
            foundFiles['decoder'] = entity;
          }
        }
        // Find joiner
        if (name.startsWith('joiner') && name.endsWith('.onnx')) {
          if (foundFiles['joiner'] == null) {
            foundFiles['joiner'] = entity;
          } else if (!name.contains('.int8') &&
              foundFiles['joiner']!.path.toLowerCase().contains('.int8')) {
            foundFiles['joiner'] = entity;
          }
        }
        // Find tokens.txt
        if (foundFiles['tokens'] == null && name == 'tokens.txt') {
          foundFiles['tokens'] = entity;
        }
      }
    }

    return foundFiles;
  }

  /// Verify model files exist and copy them to expected names if needed
  static Future<void> _verifyAndCopyModelFiles(String modelDir) async {
    final encoderFile = File('$modelDir/encoder.onnx');
    final decoderFile = File('$modelDir/decoder.onnx');
    final joinerFile = File('$modelDir/joiner.onnx');
    final tokensFile = File('$modelDir/tokens.txt');

    // If files not in root with expected names, search and rename/copy
    if (!await encoderFile.exists() ||
        !await decoderFile.exists() ||
        !await joinerFile.exists() ||
        !await tokensFile.exists()) {
      final foundFiles = await _findModelFiles(modelDir);

      // Copy/rename files to expected names in root
      if (foundFiles['encoder'] != null && !await encoderFile.exists()) {
        await foundFiles['encoder']!.copy(encoderFile.path);
      }
      if (foundFiles['decoder'] != null && !await decoderFile.exists()) {
        await foundFiles['decoder']!.copy(decoderFile.path);
      }
      if (foundFiles['joiner'] != null && !await joinerFile.exists()) {
        await foundFiles['joiner']!.copy(joinerFile.path);
      }
      if (foundFiles['tokens'] != null && !await tokensFile.exists()) {
        await foundFiles['tokens']!.copy(tokensFile.path);
      }
    }
  }
}
