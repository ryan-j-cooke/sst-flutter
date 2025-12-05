import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart';
import 'package:stttest/utils/file.dart'
    show FileDownloadHelper, CancellationToken;

// Platform-specific extraction using system tools (more memory-efficient)
Future<bool> _trySystemExtraction(
  String tarBz2Path,
  String modelDir,
  String modelName,
  SendPort sendPort,
) async {
  try {
    print(
      '[sherpa-onxx-sst] _trySystemExtraction: Attempting system tool extraction (memory-efficient)',
    );

    // Check if tar and bzip2 are available
    final tarResult = await Process.run('which', ['tar']);
    if (tarResult.exitCode != 0) {
      print(
        '[sherpa-onxx-sst] _trySystemExtraction: tar command not found, falling back to Dart implementation',
      );
      return false;
    }

    sendPort.send({'status': 'reading', 'progress': 0.0});
    print('[sherpa-onxx-sst] _trySystemExtraction: [0%] Using system tar/bzip2...');

    // Create model directory
    await Directory(modelDir).create(recursive: true);

    // Use tar with bzip2 decompression: tar -xjf archive.tar.bz2 -C destination
    // -x: extract
    // -j: filter through bzip2
    // -f: file
    // -C: change to directory
    sendPort.send({'status': 'decompressing', 'progress': 10.0});
    print('[sherpa-onxx-sst] _trySystemExtraction: [10%] Decompressing with bzip2...');

    final tarProcess = await Process.start(
      'tar',
      ['-xjf', tarBz2Path, '-C', modelDir, '--strip-components=1'],
      runInShell: false,
    );

    // Monitor process output
    final stderr = StringBuffer();
    tarProcess.stderr.transform(const SystemEncoding().decoder).listen((data) {
      stderr.write(data);
    });

    // Wait for process to complete
    final exitCode = await tarProcess.exitCode;

    if (exitCode != 0) {
      print(
        '[sherpa-onxx-sst] _trySystemExtraction: tar failed with exit code $exitCode: ${stderr.toString()}',
      );
      return false;
    }

    // Count extracted files
    int fileCount = 0;
    await for (final entity in Directory(modelDir).list(recursive: true)) {
      if (entity is File) {
        fileCount++;
      }
    }

    print(
      '[sherpa-onxx-sst] _trySystemExtraction: [100%] ✓ Extraction complete! Extracted $fileCount files',
    );
    sendPort.send({
      'status': 'completed',
      'progress': 100.0,
      'fileCount': fileCount,
    });

    return true;
  } catch (e) {
    print(
      '[sherpa-onxx-sst] _trySystemExtraction: System extraction failed: $e, falling back to Dart implementation',
    );
    return false;
  }
}

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

    print(
      '[sherpa-onxx-sst] _extractModelInIsolate: ========== Starting extraction ==========',
    );
    print('[sherpa-onxx-sst] _extractModelInIsolate: Model: $modelName');
    print('[sherpa-onxx-sst] _extractModelInIsolate: Archive: $tarBz2Path');
    print('[sherpa-onxx-sst] _extractModelInIsolate: Destination: $modelDir');
    print('');

    // Try system tools first (most memory-efficient)
    final systemExtractionSuccess = await _trySystemExtraction(
      tarBz2Path,
      modelDir,
      modelName,
      sendPort,
    );

    if (systemExtractionSuccess) {
      print(
        '[sherpa-onxx-sst] _extractModelInIsolate: ✓ System extraction succeeded, skipping Dart implementation',
      );
      return;
    }

    print(
      '[sherpa-onxx-sst] _extractModelInIsolate: Falling back to Dart archive package implementation',
    );

    sendPort.send({'status': 'reading', 'progress': 0.0});
    print(
      '[sherpa-onxx-sst] _extractModelInIsolate: [0%] Reading archive file...',
    );

    // Read the tar.bz2 file in chunks to reduce peak memory
    final tarBz2File = File(tarBz2Path);
    final fileSize = await tarBz2File.length();
    print(
      '[sherpa-onxx-sst] _extractModelInIsolate: Archive size: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB',
    );

    // For very large files, warn about memory usage
    if (fileSize > 500 * 1024 * 1024) {
      // > 500MB
      print(
        '[sherpa-onxx-sst] _extractModelInIsolate: ⚠️  WARNING - Large file detected, extraction may use significant memory',
      );
      sendPort.send({
        'status': 'warning',
        'message':
            'Large file detected (${(fileSize / 1024 / 1024).toStringAsFixed(1)} MB). Extraction may use significant memory.',
      });
    }

    // Read file - this is still necessary for bzip2 decompression
    tarBz2Bytes = await tarBz2File.readAsBytes();
    print(
      '[sherpa-onxx-sst] _extractModelInIsolate: [10%] ✓ Read ${(tarBz2Bytes.length / 1024 / 1024).toStringAsFixed(2)} MB into memory',
    );
    sendPort.send({
      'status': 'read',
      'progress': 10.0,
      'size': tarBz2Bytes.length,
    });

    // Decompress bzip2
    print(
      '[sherpa-onxx-sst] _extractModelInIsolate: [15%] Decompressing bzip2 archive...',
    );
    sendPort.send({'status': 'decompressing', 'progress': 15.0});
    final bz2Decoder = BZip2Decoder();
    tarBytes = bz2Decoder.decodeBytes(tarBz2Bytes);

    // Clear compressed bytes from memory immediately after decompression
    tarBz2Bytes = null;
    
    // Yield control to allow GC to reclaim memory
    await Future.delayed(const Duration(milliseconds: 50));

    print(
      '[sherpa-onxx-sst] _extractModelInIsolate: [40%] ✓ Decompressed to ${(tarBytes.length / 1024 / 1024).toStringAsFixed(2)} MB',
    );
    sendPort.send({
      'status': 'decompressed',
      'progress': 40.0,
      'size': tarBytes.length,
    });

    // Extract tar archive
    print(
      '[sherpa-onxx-sst] _extractModelInIsolate: [45%] Decoding tar archive...',
    );
    sendPort.send({'status': 'decoding', 'progress': 45.0});
    final tarDecoder = TarDecoder();
    archive = tarDecoder.decodeBytes(tarBytes);

    // Clear tar bytes from memory after decoding
    tarBytes = null;
    
    // Yield control to allow GC to reclaim memory
    await Future.delayed(const Duration(milliseconds: 50));
    
    // Yield control to allow GC to reclaim memory
    await Future.delayed(const Duration(milliseconds: 50));

    print(
      '[sherpa-onxx-sst] _extractModelInIsolate: [50%] ✓ Decoded ${archive.files.length} files from tar archive',
    );
    sendPort.send({
      'status': 'decoded',
      'progress': 50.0,
      'fileCount': archive.files.length,
    });

    // Extract all files one at a time, clearing file content after writing
    // Process files immediately and clear content to reduce memory pressure
    int fileCount = 0;
    final fileList = archive.files.where((f) => f.isFile).toList();
    final totalFiles = fileList.length;

    print(
      '[sherpa-onxx-sst] _extractModelInIsolate: [50%] Starting extraction of $totalFiles files...',
    );
    print('');

    // Process files in batches with delays to allow GC
    const batchSize = 3; // Process 3 files, then yield
    for (int i = 0; i < fileList.length; i++) {
      final file = fileList[i];
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
      final progressPercent = (50.0 + (fileCount / totalFiles) * 50.0)
          .toStringAsFixed(1);

      try {
        await outputFile.parent.create(recursive: true);

        // Write file content
        final content = file.content;
        final fileSize = content is List<int>
            ? content.length
            : (content is Uint8List ? content.length : 0);

        if (content is List<int>) {
          await outputFile.writeAsBytes(content);
        } else if (content is Uint8List) {
          await outputFile.writeAsBytes(content);
        }

        // Log extracted file
        final sizeStr = fileSize > 1024 * 1024
            ? '${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB'
            : fileSize > 1024
            ? '${(fileSize / 1024).toStringAsFixed(2)} KB'
            : '$fileSize B';
        print(
          '[sherpa-onxx-sst] _extractModelInIsolate: [$progressPercent%] ✓ Extracted ($fileCount/$totalFiles): $relativePath ($sizeStr)',
        );

        // Log all extracted files for debugging
        sendPort.send({
          'status': 'extracting',
          'progress': 50.0 + (fileCount / totalFiles) * 50.0,
          'fileCount': fileCount,
          'totalFiles': totalFiles,
          'currentFile': filename,
          'extractedPath': outputFile.path,
          'extractedFileName': relativePath,
          'logFile': true,
        });

        // Clear file content reference after writing (help GC)
        // Note: file.content is still in memory in the archive, but we've written it
        
        // Try to clear file content if possible (archive package limitation)
        // The archive keeps references, but we've written the file
        
      } catch (e) {
        print(
          '[sherpa-onxx-sst] _extractModelInIsolate: ✗ ERROR extracting $filename: $e',
        );
        sendPort.send({'error': 'Failed to extract $filename: $e'});
      }

      // Yield control every batchSize files to allow GC and reduce memory pressure
      if (i > 0 && i % batchSize == 0) {
        await Future.delayed(const Duration(milliseconds: 10));
        // Force a small delay to allow GC
      }
    }

    // Clear archive reference
    archive = null;

    print(
      '[sherpa-onxx-sst] _extractModelInIsolate: [100%] ✓ Extraction complete! Extracted $fileCount files',
    );
    print(
      '[sherpa-onxx-sst] _extractModelInIsolate: ========== Extraction finished ==========',
    );
    print('');

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
      final modelDir = '${documentsDir.path}/sherpa_onnx_models/$modelName';
      print('[sherpa-onxx-sst] modelExistsByName: Model directory=$modelDir');

      // Determine model type
      final isWhisperModel = modelName.contains('whisper');
      final isParaformerModel = modelName.contains('paraformer');
      print(
        '[sherpa-onxx-sst] modelExistsByName: Is Whisper model: $isWhisperModel',
      );
      print(
        '[sherpa-onxx-sst] modelExistsByName: Is Paraformer model: $isParaformerModel',
      );

      if (isParaformerModel) {
        // Paraformer models use a single model.onnx file
        final modelFile = File('$modelDir/model.onnx');
        final tokensFile = File('$modelDir/tokens.txt');
        
        final modelExists = await modelFile.exists();
        final tokensExists = await tokensFile.exists();
        
        print(
          '[sherpa-onxx-sst] modelExistsByName: model.onnx exists: $modelExists',
        );
        print('[sherpa-onxx-sst] modelExistsByName: tokensExists=$tokensExists');
        
        final allExist = modelExists && tokensExists;
        print('[sherpa-onxx-sst] modelExistsByName: Result=$allExist');
        return allExist;
      }

      // Transducer/Zipformer models use encoder/decoder/joiner files
      final encoderFile = File('$modelDir/encoder.onnx');
      final decoderFile = File('$modelDir/decoder.onnx');
      final joinerFile = File('$modelDir/joiner.onnx');
      final tokensFile = File('$modelDir/tokens.txt');

      final encoderExists = await encoderFile.exists();
      final decoderExists = await decoderFile.exists();
      final joinerExists = await joinerFile.exists();
      final tokensExists = await tokensFile.exists();

      print(
        '[sherpa-onxx-sst] modelExistsByName: encoderExists=$encoderExists',
      );
      print(
        '[sherpa-onxx-sst] modelExistsByName: decoderExists=$decoderExists',
      );
      print('[sherpa-onxx-sst] modelExistsByName: joinerExists=$joinerExists');
      print('[sherpa-onxx-sst] modelExistsByName: tokensExists=$tokensExists');

      // For Whisper models, joiner is not required
      final allExist =
          encoderExists &&
          decoderExists &&
          tokensExists &&
          (isWhisperModel || joinerExists);
      print('[sherpa-onxx-sst] modelExistsByName: Result=$allExist');
      return allExist;
    } catch (e) {
      print('[sherpa-onxx-sst] modelExistsByName: ERROR - $e');
      return false;
    }
  }

  /// Ensure model exists, downloading and extracting if necessary (using enum)
  ///
  /// Returns the model directory path
  static Future<String> ensureModelExists(SherpaModelType model) async {
    return ensureModelExistsByName(model.modelName);
  }

  /// Ensure model exists, downloading and extracting if necessary (using model name string)
  ///
  /// Returns the model directory path
  static Future<String> ensureModelExistsByName(String modelName) async {
    print(
      '[sherpa-onxx-sst] ensureModelExistsByName: Starting for model=$modelName',
    );
    // Get model directory
    final documentsDir = await getApplicationDocumentsDirectory();
    final modelDir = '${documentsDir.path}/sherpa_onnx_models/$modelName';
    print(
      '[sherpa-onxx-sst] ensureModelExistsByName: Model directory=$modelDir',
    );
    await Directory(modelDir).create(recursive: true);

    // Determine model type
    final isWhisperModel = modelName.contains('whisper');
    final isParaformerModel = modelName.contains('paraformer');
    print(
      '[sherpa-onxx-sst] ensureModelExistsByName: Is Whisper model: $isWhisperModel',
    );
    print(
      '[sherpa-onxx-sst] ensureModelExistsByName: Is Paraformer model: $isParaformerModel',
    );

    bool modelExists = false;
    
    if (isParaformerModel) {
      // Paraformer models use a single model.onnx file
      final modelFile = File('$modelDir/model.onnx');
      final tokensFile = File('$modelDir/tokens.txt');
      
      final modelFileExists = await modelFile.exists();
      final tokensExists = await tokensFile.exists();
      
      modelExists = modelFileExists && tokensExists;
      print(
        '[sherpa-onxx-sst] ensureModelExistsByName: Model files exist=$modelExists',
      );
      print(
        '[sherpa-onxx-sst] ensureModelExistsByName: model.onnx exists=$modelFileExists, tokensExists=$tokensExists',
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
      modelExists =
          encoderExists &&
          decoderExists &&
          tokensExists &&
          (isWhisperModel || joinerExists);
      print(
        '[sherpa-onxx-sst] ensureModelExistsByName: Model files exist=$modelExists',
      );
      print(
        '[sherpa-onxx-sst] ensureModelExistsByName: encoderExists=$encoderExists, decoderExists=$decoderExists, joinerExists=$joinerExists, tokensExists=$tokensExists',
      );
    }

    if (!modelExists) {
      // Model doesn't exist, check if downloaded file exists
      final tempDir = await getTemporaryDirectory();
      final downloadedFile = File('${tempDir.path}/$modelName.tar.bz2');

      if (await downloadedFile.exists()) {
        // Check file size against remote
        try {
          final localSize = await downloadedFile.length();
          final remoteSize = await _getRemoteFileSize(
            'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/$modelName.tar.bz2',
          );

          if (remoteSize != null && localSize == remoteSize) {
            // File exists and size matches, extract it
            await _extractModel(downloadedFile, modelDir, modelName);
          } else {
            // Size doesn't match, re-download
            await downloadedFile.delete();
            await _downloadModelByName(modelName);
            final redownloadedFile = File('${tempDir.path}/$modelName.tar.bz2');
            await _extractModel(redownloadedFile, modelDir, modelName);
          }
        } catch (e) {
          // If we can't check, re-download to be safe
          if (await downloadedFile.exists()) {
            await downloadedFile.delete();
          }
          await _downloadModelByName(modelName);
          final redownloadedFile = File('${tempDir.path}/$modelName.tar.bz2');
          await _extractModel(redownloadedFile, modelDir, modelName);
        }
      } else {
        // No downloaded file, download it
        await _downloadModelByName(modelName);
        final tempDir2 = await getTemporaryDirectory();
        final downloadedFile2 = File('${tempDir2.path}/$modelName.tar.bz2');
        await _extractModel(downloadedFile2, modelDir, modelName);
      }
    }

    return modelDir;
  }

  /// Initialize Sherpa-ONNX recognizer (using enum)
  ///
  /// Returns the initialized OfflineRecognizer
  /// This method performs file checks in an isolate to avoid blocking the UI
  static Future<OfflineRecognizer> initializeRecognizer(
    SherpaModelType model,
  ) async {
    return initializeRecognizerByName(
      model.modelName,
      displayName: model.displayName,
    );
  }

  /// Initialize Sherpa-ONNX recognizer (using model name string)
  ///
  /// Returns the initialized OfflineRecognizer
  /// This method performs file checks in an isolate to avoid blocking the UI
  static Future<OfflineRecognizer> initializeRecognizerByName(
    String modelName, {
    String? displayName,
  }) async {
    print(
      '[sherpa-onxx-sst] initializeRecognizerByName: Starting for model=${displayName ?? modelName} ($modelName)',
    );

    // Ensure model exists (download/extract if needed) - this is already async
    final modelDir = await ensureModelExistsByName(modelName);
    print(
      '[sherpa-onxx-sst] initializeRecognizerByName: Model directory=$modelDir',
    );

    // Determine model type
    final isWhisperModel = modelName.contains('whisper');
    final isParaformerModel = modelName.contains('paraformer');
    
    print('[sherpa-onxx-sst] initializeRecognizerByName: Checking files...');
    print(
      '[sherpa-onxx-sst] initializeRecognizerByName: Is Whisper model: $isWhisperModel',
    );
    print(
      '[sherpa-onxx-sst] initializeRecognizerByName: Is Paraformer model: $isParaformerModel',
    );

    if (isParaformerModel) {
      // Paraformer models use a single model.onnx file
      final modelPath = '$modelDir/model.onnx';
      final tokensPath = '$modelDir/tokens.txt';

      print(
        '[sherpa-onxx-sst] initializeRecognizerByName: modelPath=$modelPath',
      );
      print(
        '[sherpa-onxx-sst] initializeRecognizerByName: tokensPath=$tokensPath',
      );

      // Check files exist
      final modelFile = File(modelPath);
      final tokensFile = File(tokensPath);
      
      final modelExists = await modelFile.exists();
      final tokensExists = await tokensFile.exists();

      print(
        '[sherpa-onxx-sst] initializeRecognizerByName: model.onnx exists: $modelExists',
      );
      print(
        '[sherpa-onxx-sst] initializeRecognizerByName: tokensExists=$tokensExists',
      );

      if (!modelExists || !tokensExists) {
        print(
          '[sherpa-onxx-sst] initializeRecognizerByName: ERROR - Paraformer model files missing!',
        );
        throw Exception('Paraformer model files missing');
      }

      // Yield control to UI thread
      await Future.delayed(const Duration(milliseconds: 50));

      print(
        '[sherpa-onxx-sst] initializeRecognizerByName: All files exist, creating Paraformer recognizer config...',
      );

      // Use Paraformer config
      final modelConfig = OfflineModelConfig(
        paraformer: OfflineParaformerModelConfig(model: modelPath),
        tokens: tokensPath,
      );

      final recognizerConfig = OfflineRecognizerConfig(
        model: modelConfig,
        feat: FeatureConfig(sampleRate: 16000),
      );

      // Yield control multiple times before creating recognizer (this is the heavy operation)
      await Future.delayed(const Duration(milliseconds: 100));
      await Future.delayed(Duration.zero);
      await Future.delayed(Duration.zero);

      print(
        '[sherpa-onxx-sst] initializeRecognizerByName: Creating OfflineRecognizer (Paraformer)...',
      );
      final recognizer = OfflineRecognizer(recognizerConfig);
      print(
        '[sherpa-onxx-sst] initializeRecognizerByName: Recognizer created successfully',
      );
      
      // Yield after creation to allow UI to update
      await Future.delayed(Duration.zero);
      
      return recognizer;
    }

    // Transducer/Zipformer models use encoder/decoder/joiner files
    final encoderPath = '$modelDir/encoder.onnx';
    final decoderPath = '$modelDir/decoder.onnx';
    final joinerPath = '$modelDir/joiner.onnx';
    final tokensPath = '$modelDir/tokens.txt';

    print(
      '[sherpa-onxx-sst] initializeRecognizerByName: encoderPath=$encoderPath',
    );
    print(
      '[sherpa-onxx-sst] initializeRecognizerByName: decoderPath=$decoderPath',
    );
    print(
      '[sherpa-onxx-sst] initializeRecognizerByName: joinerPath=$joinerPath',
    );
    print(
      '[sherpa-onxx-sst] initializeRecognizerByName: tokensPath=$tokensPath',
    );

    // Perform file existence checks in an isolate to avoid blocking UI
    final fileCheckResult = await _checkModelFilesInIsolate(
      encoderPath,
      decoderPath,
      joinerPath,
      tokensPath,
    );

    print(
      '[sherpa-onxx-sst] initializeRecognizerByName: encoderExists=${fileCheckResult['encoderExists']}',
    );
    print(
      '[sherpa-onxx-sst] initializeRecognizerByName: decoderExists=${fileCheckResult['decoderExists']}',
    );
    print(
      '[sherpa-onxx-sst] initializeRecognizerByName: joinerExists=${fileCheckResult['joinerExists']}',
    );
    print(
      '[sherpa-onxx-sst] initializeRecognizerByName: tokensExists=${fileCheckResult['tokensExists']}',
    );

    // For Whisper models, joiner is not required
    final requiredFilesExist =
        fileCheckResult['encoderExists']! &&
        fileCheckResult['decoderExists']! &&
        fileCheckResult['tokensExists']! &&
        (isWhisperModel || fileCheckResult['joinerExists']!);

    if (!requiredFilesExist) {
      print(
        '[sherpa-onxx-sst] initializeRecognizerByName: ERROR - Model files missing!',
      );
      throw Exception('Model files missing');
    }

    // Yield control to UI thread to allow loading indicator to show
    // Use a small delay to ensure UI has time to update
    await Future.delayed(const Duration(milliseconds: 50));

    print(
      '[sherpa-onxx-sst] initializeRecognizerByName: All files exist, creating recognizer config...',
    );

    // Use Whisper config for Whisper models, Transducer config for others
    final modelConfig = isWhisperModel
        ? OfflineModelConfig(
            whisper: OfflineWhisperModelConfig(
              encoder: encoderPath,
              decoder: decoderPath,
              language: '', // Auto-detect language
              task: 'transcribe',
              tailPaddings: -1,
            ),
            tokens: tokensPath,
          )
        : OfflineModelConfig(
            transducer: OfflineTransducerModelConfig(
              encoder: encoderPath,
              decoder: decoderPath,
              joiner: joinerPath,
            ),
            tokens: tokensPath,
          );

    final recognizerConfig = OfflineRecognizerConfig(
      model: modelConfig,
      feat: FeatureConfig(sampleRate: 16000),
    );

    // Yield control again before creating recognizer (this is the heavy operation)
    // This allows the UI to show the loading state before blocking
    await Future.delayed(const Duration(milliseconds: 50));

    print(
      '[sherpa-onxx-sst] initializeRecognizerByName: Creating OfflineRecognizer...',
    );
    // Note: OfflineRecognizer creation must happen on main thread (native object)
    // This is the blocking operation, but we've already shown loading state
    final recognizer = OfflineRecognizer(recognizerConfig);
    print(
      '[sherpa-onxx-sst] initializeRecognizerByName: Recognizer created successfully',
    );
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
    print(
      '[sherpa-onxx-sst] transcribeAudio: onPartialResult provided=${onPartialResult != null}',
    );

    // Read audio file in an isolate to avoid blocking UI
    print('[sherpa-onxx-sst] transcribeAudio: Reading audio file in isolate...');
    final audioBytes = await _readAudioFileInIsolate(audioPath);
    print(
      '[sherpa-onxx-sst] transcribeAudio: Audio file read, size=${audioBytes.length} bytes',
    );

    // Yield control to UI thread after file reading
    await Future.delayed(Duration.zero);

    // Create offline stream for transcription
    final stream = recognizer.createStream();
    print('[sherpa-onxx-sst] transcribeAudio: Stream created');

    try {
      // Process audio in chunks (16kHz, 16-bit, mono = 32000 bytes per second)
      // 100ms chunks = 3200 bytes per chunk
      const chunkSize = 3200; // 100ms chunks
      final totalChunks = (audioBytes.length / chunkSize).ceil();
      print(
        '[sherpa-onxx-sst] transcribeAudio: Processing $totalChunks chunks',
      );

      // Process audio in batches to reduce isolate overhead
      // Batch size: 5 chunks per isolate call
      const batchSize = 5;
      final chunks = <List<int>>[];
      for (int i = 0; i < audioBytes.length; i += chunkSize) {
        final end = (i + chunkSize < audioBytes.length)
            ? i + chunkSize
            : audioBytes.length;
        chunks.add(audioBytes.sublist(i, end));
      }

      int chunkCount = 0;
      for (int batchStart = 0; batchStart < chunks.length; batchStart += batchSize) {
        final batchEnd = (batchStart + batchSize < chunks.length)
            ? batchStart + batchSize
            : chunks.length;
        final batch = chunks.sublist(batchStart, batchEnd);

        // Convert batch of chunks to samples in an isolate
        final samplesBatch = await _bytesToSamplesBatchInIsolate(batch);

        // Yield control after batch conversion
        await Future.delayed(Duration.zero);

        // Feed each sample batch to recognizer
        for (final samples in samplesBatch) {
          stream.acceptWaveform(
            samples: samples,
            sampleRate: 16000,
          );

          chunkCount++;

          // Yield control to UI thread after every chunk to keep UI responsive
          await Future.delayed(Duration.zero);

          // Get partial results periodically (every 10 chunks = ~1 second of audio)
          if (onPartialResult != null && chunkCount % 10 == 0) {
            try {
              // Yield before decode to ensure UI updates
              await Future.delayed(Duration.zero);
              recognizer.decode(stream);
              final partialResult = recognizer.getResult(stream);
              if (partialResult.text.isNotEmpty) {
                print(
                  '[sherpa-onxx-sst] transcribeAudio: Partial result: "${partialResult.text}"',
                );
                // Yield control before calling callback to ensure UI updates
                await Future.delayed(Duration.zero);
                onPartialResult(partialResult.text);
              }
            } catch (e) {
              // Ignore errors for partial results
              print(
                '[sherpa-onxx-sst] transcribeAudio: Error getting partial result: $e',
              );
            }
          }
        }

        // Yield control after processing each batch
        await Future.delayed(Duration.zero);
      }

      print(
        '[sherpa-onxx-sst] transcribeAudio: All chunks processed, getting final result...',
      );
      
      // Yield before final decode
      await Future.delayed(Duration.zero);
      
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

  /// Read audio file in an isolate to avoid blocking UI
  static Future<Uint8List> _readAudioFileInIsolate(String audioPath) async {
    final receivePort = ReceivePort();

    await Isolate.spawn(_readAudioFileIsolate, {
      'sendPort': receivePort.sendPort,
      'audioPath': audioPath,
    });

    final result = await receivePort.first;
    if (result is Exception) {
      throw result;
    }
    return result as Uint8List;
  }

  /// Isolate entry point for reading audio file
  static void _readAudioFileIsolate(Map<String, dynamic> message) {
    final sendPort = message['sendPort'] as SendPort;
    final audioPath = message['audioPath'] as String;

    try {
      final audioFile = File(audioPath);
      if (!audioFile.existsSync()) {
        sendPort.send(Exception('Audio file not found: $audioPath'));
        return;
      }
      final audioBytes = audioFile.readAsBytesSync();
      sendPort.send(audioBytes);
    } catch (e) {
      sendPort.send(Exception('Error reading audio file: $e'));
    }
  }

  /// Convert bytes to float samples in an isolate to avoid blocking UI
  /// Batches multiple chunks to reduce isolate spawn overhead
  static Future<List<Float32List>> _bytesToSamplesBatchInIsolate(
      List<List<int>> chunks) async {
    final receivePort = ReceivePort();

    await Isolate.spawn(_bytesToSamplesBatchIsolate, {
      'sendPort': receivePort.sendPort,
      'chunks': chunks,
    });

    final result = await receivePort.first as List<Float32List>;
    return result;
  }

  /// Isolate entry point for batch bytes to samples conversion
  static void _bytesToSamplesBatchIsolate(Map<String, dynamic> message) {
    final sendPort = message['sendPort'] as SendPort;
    final chunks = message['chunks'] as List<List<int>>;

    try {
      final results = <Float32List>[];
      for (final bytes in chunks) {
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
        results.add(samples);
      }
      sendPort.send(results);
    } catch (e) {
      // On error, return empty lists
      sendPort.send(List<Float32List>.filled(chunks.length, Float32List(0)));
    }
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

  /// Download model from GitHub releases with progress tracking and cancellation (using enum)
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
    return downloadModelByName(
      model.modelName,
      modelDir,
      displayName: model.displayName,
      onProgress: onProgress,
      onExtractionProgress: onExtractionProgress,
      cancelToken: cancelToken,
    );
  }

  /// Download model from GitHub releases with progress tracking and cancellation (using model name string)
  ///
  /// [onProgress] - Callback for download progress: (downloadedBytes, totalBytes)
  /// [onExtractionProgress] - Optional callback for extraction progress: (progress, status)
  ///   progress: 0.0 to 100.0, status: human-readable status string
  static Future<void> downloadModelByName(
    String modelName,
    String modelDir, {
    String? displayName,
    void Function(int downloaded, int? total)? onProgress,
    void Function(double progress, String status)? onExtractionProgress,
    CancellationToken? cancelToken,
  }) async {
    print(
      '[sherpa-onxx-sst] downloadModelByName: ========== Starting download process ==========',
    );
    print(
      '[sherpa-onxx-sst] downloadModelByName: Model=${displayName ?? modelName} ($modelName)',
    );
    print(
      '[sherpa-onxx-sst] downloadModelByName: Model directory (destination for extracted files)=$modelDir',
    );

    final modelUrl =
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/$modelName.tar.bz2';
    print('[sherpa-onxx-sst] downloadModelByName: Model URL=$modelUrl');

    // First, check if model files already exist
    final encoderFile = File('$modelDir/encoder.onnx');
    final decoderFile = File('$modelDir/decoder.onnx');
    final joinerFile = File('$modelDir/joiner.onnx');
    final tokensFile = File('$modelDir/tokens.txt');

    print(
      '[sherpa-onxx-sst] downloadModelByName: Checking model files existence...',
    );
    print(
      '[sherpa-onxx-sst] downloadModelByName: - encoder.onnx: ${encoderFile.path}',
    );
    print(
      '[sherpa-onxx-sst] downloadModelByName: - decoder.onnx: ${decoderFile.path}',
    );
    print(
      '[sherpa-onxx-sst] downloadModelByName: - joiner.onnx: ${joinerFile.path}',
    );
    print(
      '[sherpa-onxx-sst] downloadModelByName: - tokens.txt: ${tokensFile.path}',
    );

    final encoderExists = await encoderFile.exists();
    final decoderExists = await decoderFile.exists();
    final joinerExists = await joinerFile.exists();
    final tokensExists = await tokensFile.exists();

    print(
      '[sherpa-onxx-sst] downloadModelByName: File existence check results:',
    );
    print(
      '[sherpa-onxx-sst] downloadModelByName: - encoder.onnx exists: $encoderExists',
    );
    print(
      '[sherpa-onxx-sst] downloadModelByName: - decoder.onnx exists: $decoderExists',
    );
    print(
      '[sherpa-onxx-sst] downloadModelByName: - joiner.onnx exists: $joinerExists',
    );
    print(
      '[sherpa-onxx-sst] downloadModelByName: - tokens.txt exists: $tokensExists',
    );

    // Determine if this is a Whisper model (no joiner required)
    final isWhisperModel = modelName.contains('whisper');
    print(
      '[sherpa-onxx-sst] downloadModelByName: Is Whisper model: $isWhisperModel',
    );

    // For Whisper models, joiner is not required
    final modelFilesExist =
        encoderExists &&
        decoderExists &&
        tokensExists &&
        (isWhisperModel || joinerExists);

    if (modelFilesExist) {
      print(
        '[sherpa-onxx-sst] downloadModelByName: ✓ All model files already exist, skipping download and extraction',
      );
      print(
        '[sherpa-onxx-sst] downloadModelByName: ========== Download process complete (no action needed) ==========',
      );
      return;
    }

    // Model files don't exist, check if .tar.bz2 file exists
    final tempDir = await getTemporaryDirectory();
    final tempFilePath = '${tempDir.path}/$modelName.tar.bz2';
    final downloadedFile = File(tempFilePath);

    print(
      '[sherpa-onxx-sst] downloadModelByName: Model files missing, checking for compressed file...',
    );
    print(
      '[sherpa-onxx-sst] downloadModelByName: Compressed file location (destination for download)=$tempFilePath',
    );

    final compressedFileExists = await downloadedFile.exists();
    print(
      '[sherpa-onxx-sst] downloadModelByName: Compressed file (.tar.bz2) exists: $compressedFileExists',
    );

    if (compressedFileExists) {
      final compressedFileSize = await downloadedFile.length();
      print(
        '[sherpa-onxx-sst] downloadModelByName: Compressed file size: ${(compressedFileSize / 1024 / 1024).toStringAsFixed(2)} MB',
      );
      print(
        '[sherpa-onxx-sst] downloadModelByName: Found existing .tar.bz2 file, verifying size...',
      );

      // Verify file size matches remote (to ensure it's complete)
      try {
        final localSize = await downloadedFile.length();
        final remoteSize = await _getRemoteFileSize(modelUrl);

        if (remoteSize != null && localSize == remoteSize) {
          print(
            '[sherpa-onxx-sst] downloadModelByName: ✓ Compressed file size matches remote (${(localSize / 1024 / 1024).toStringAsFixed(1)} MB)',
          );
          print(
            '[sherpa-onxx-sst] downloadModelByName: Skipping download, proceeding directly to extraction',
          );
          print(
            '[sherpa-onxx-sst] downloadModelByName: Extraction destination: $modelDir',
          );
          // File exists and size matches, skip download and go straight to extraction
          await _extractModel(
            downloadedFile,
            modelDir,
            modelName,
            onProgress: onExtractionProgress,
          );
          print(
            '[sherpa-onxx-sst] downloadModelByName: ========== Download process complete (extraction finished) ==========',
          );
          return;
        } else {
          print(
            '[sherpa-onxx-sst] downloadModelByName: ✗ Compressed file size mismatch (local: ${(localSize / 1024 / 1024).toStringAsFixed(2)} MB, remote: ${remoteSize != null ? (remoteSize / 1024 / 1024).toStringAsFixed(2) : "unknown"} MB)',
          );
          print(
            '[sherpa-onxx-sst] downloadModelByName: Deleting invalid compressed file and re-downloading...',
          );
          // Size doesn't match, delete and re-download
          await downloadedFile.delete();
        }
      } catch (e) {
        print(
          '[sherpa-onxx-sst] downloadModelByName: ✗ Error verifying existing file: $e',
        );
        print(
          '[sherpa-onxx-sst] downloadModelByName: Deleting compressed file and re-downloading...',
        );
        // If we can't verify, delete and re-download to be safe
        if (await downloadedFile.exists()) {
          await downloadedFile.delete();
        }
      }
    }

    // .tar.bz2 file doesn't exist or was invalid, download it
    print(
      '[sherpa-onxx-sst] downloadModelByName: Starting download from: $modelUrl',
    );
    print(
      '[sherpa-onxx-sst] downloadModelByName: Download destination: $tempFilePath',
    );
    print(
      '[sherpa-onxx-sst] downloadModelByName: Extraction will occur to: $modelDir',
    );
    await FileDownloadHelper.downloadFile(
      Uri.parse(modelUrl),
      tempFilePath,
      onProgress: onProgress,
      cancelToken: cancelToken,
    );

    // After download, extract the model
    if (await downloadedFile.exists()) {
      final downloadedSize = await downloadedFile.length();
      print(
        '[sherpa-onxx-sst] downloadModelByName: ✓ Download complete, file size: ${(downloadedSize / 1024 / 1024).toStringAsFixed(2)} MB',
      );
      print(
        '[sherpa-onxx-sst] downloadModelByName: Starting extraction to: $modelDir',
      );
      await _extractModel(
        downloadedFile,
        modelDir,
        modelName,
        onProgress: onExtractionProgress,
      );
      print(
        '[sherpa-onxx-sst] downloadModelByName: ========== Download process complete (download + extraction finished) ==========',
      );
    } else {
      print(
        '[sherpa-onxx-sst] downloadModelByName: ✗ ERROR: Downloaded file does not exist after download',
      );
      print(
        '[sherpa-onxx-sst] downloadModelByName: ========== Download process failed ==========',
      );
    }
  }

  /// Download model from GitHub releases (internal use, using enum)
  static Future<void> _downloadModel(SherpaModelType model) async {
    return _downloadModelByName(model.modelName);
  }

  /// Download model from GitHub releases (internal use, using model name string)
  static Future<void> _downloadModelByName(String modelName) async {
    final modelUrl =
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/$modelName.tar.bz2';

    // Download to temporary file first
    final tempDir = await getTemporaryDirectory();
    final tempFilePath = '${tempDir.path}/$modelName.tar.bz2';

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

    // Determine if this is a Whisper model (no joiner) - try to infer from modelDir or check files
    final isWhisperModel = modelDir.contains('whisper');

    // Check if all required files exist with expected names
    // For Whisper models, joiner is not required
    final allFilesExist =
        await encoderFile.exists() &&
        await decoderFile.exists() &&
        await tokensFile.exists() &&
        (isWhisperModel || await joinerFile.exists());

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
    print(
      '[sherpa-onxx-sst] _extractModel: ========== Starting extraction process ==========',
    );
    print('[sherpa-onxx-sst] _extractModel: Archive: ${tarBz2File.path}');
    print('[sherpa-onxx-sst] _extractModel: Destination: $modelDir');
    print('[sherpa-onxx-sst] _extractModel: Model: $modelName');
    print('');

    // Create a receive port to get progress updates from the isolate
    final receivePort = ReceivePort();

    // Spawn isolate for background extraction
    print(
      '[sherpa-onxx-sst] _extractModel: Spawning isolate for background extraction...',
    );
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
          final errorMsg = message['error'] as String;
          final stackTrace = message['stackTrace'] as String?;
          print('[sherpa-onxx-sst] _extractModel: ✗✗✗ EXTRACTION ERROR ✗✗✗');
          print('[sherpa-onxx-sst] _extractModel: Error: $errorMsg');
          if (stackTrace != null) {
            print('[sherpa-onxx-sst] _extractModel: Stack trace: $stackTrace');
          }
          print(
            '[sherpa-onxx-sst] _extractModel: ========== Extraction failed ==========',
          );
          print('');
          throw Exception(errorMsg);
        }

        final status = message['status'] as String?;
        final progress = (message['progress'] as num?)?.toDouble() ?? 0.0;
        final fileCount = message['fileCount'] as int?;
        final totalFiles = message['totalFiles'] as int?;
        final currentFile = message['currentFile'] as String?;
        final extractedPath = message['extractedPath'] as String?;
        final extractedFileName = message['extractedFileName'] as String?;
        final logFile = message['logFile'] as bool? ?? false;

        // Log extracted file paths for debugging
        if (logFile && extractedPath != null) {
          print(
            '[sherpa-onxx-sst] _extractModel: Extracted file: $extractedFileName -> $extractedPath',
          );
        }

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

        // Log progress to console
        final progressPercent = progress.toStringAsFixed(1);
        switch (status) {
          case 'reading':
            print(
              '[sherpa-onxx-sst] _extractModel: [$progressPercent%] Reading archive file...',
            );
            break;
          case 'read':
            final size = message['size'] as int?;
            if (size != null) {
              print(
                '[sherpa-onxx-sst] _extractModel: [$progressPercent%] ✓ Read ${(size / 1024 / 1024).toStringAsFixed(2)} MB',
              );
            }
            break;
          case 'decompressing':
            print(
              '[sherpa-onxx-sst] _extractModel: [$progressPercent%] Decompressing bzip2 archive...',
            );
            break;
          case 'decompressed':
            final size = message['size'] as int?;
            if (size != null) {
              print(
                '[sherpa-onxx-sst] _extractModel: [$progressPercent%] ✓ Decompressed to ${(size / 1024 / 1024).toStringAsFixed(2)} MB',
              );
            }
            break;
          case 'decoding':
            print(
              '[sherpa-onxx-sst] _extractModel: [$progressPercent%] Decoding tar archive...',
            );
            break;
          case 'decoded':
            final fileCount = message['fileCount'] as int?;
            if (fileCount != null) {
              print(
                '[sherpa-onxx-sst] _extractModel: [$progressPercent%] ✓ Decoded $fileCount files from tar archive',
              );
            }
            break;
          case 'extracting':
            if (fileCount != null &&
                totalFiles != null &&
                currentFile != null) {
              final fileName = currentFile.split('/').last;
              print(
                '[sherpa-onxx-sst] _extractModel: [$progressPercent%] Extracting file $fileCount/$totalFiles: $fileName',
              );
            }
            break;
          case 'completed':
            final fileCount = message['fileCount'] as int?;
            if (fileCount != null) {
              print(
                '[sherpa-onxx-sst] _extractModel: [$progressPercent%] ✓✓✓ EXTRACTION COMPLETE ✓✓✓',
              );
              print(
                '[sherpa-onxx-sst] _extractModel: Successfully extracted $fileCount files',
              );
              print(
                '[sherpa-onxx-sst] _extractModel: ========== Extraction process finished ==========',
              );
              print('');
            }
            break;
          case 'warning':
            final warningMsg = message['message'] as String?;
            if (warningMsg != null) {
              print(
                '[sherpa-onxx-sst] _extractModel: ⚠️  WARNING: $warningMsg',
              );
            }
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
    // Determine model type from modelName to pass to verification
    SherpaModelType? modelType;
    try {
      modelType = SherpaModelType.values.firstWhere(
        (m) => m.modelName == modelName,
        orElse: () => SherpaModelType.zipformerEn, // Default fallback
      );
    } catch (e) {
      print(
        '[sherpa-onxx-sst] _extractModel: Could not determine model type from name: $modelName',
      );
    }
    await _verifyAndCopyModelFiles(
      modelDir,
      model: modelType,
      modelName: modelName,
    );
  }

  /// Find model files in the model directory (recursively)
  static Future<Map<String, File?>> _findModelFiles(String modelDir) async {
    print(
      '[sherpa-onxx-sst] _findModelFiles: Searching for model files in: $modelDir',
    );
    final foundFiles = <String, File?>{
      'encoder': null,
      'decoder': null,
      'joiner': null,
      'tokens': null,
    };

    final dir = Directory(modelDir);
    if (!await dir.exists()) {
      print(
        '[sherpa-onxx-sst] _findModelFiles: Directory does not exist: $modelDir',
      );
      return foundFiles;
    }

    int fileCount = 0;
    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        fileCount++;
        final name = entity.path.split('/').last.toLowerCase();
        final fullPath = entity.path;

        // Log all .onnx and .txt files for debugging
        if (name.endsWith('.onnx') || name.endsWith('.txt')) {
          print('[sherpa-onxx-sst] _findModelFiles: Found file: $fullPath');
        }

        // Find encoder (look for files containing "encoder" and ending with ".onnx")
        // Handles both "encoder.onnx" and "tiny-encoder.onnx" patterns
        // Prefer non-INT8 versions
        if (name.contains('encoder') && name.endsWith('.onnx')) {
          if (foundFiles['encoder'] == null) {
            foundFiles['encoder'] = entity;
            print(
              '[sherpa-onxx-sst] _findModelFiles: Found encoder candidate: $fullPath',
            );
          } else if (!name.contains('.int8') &&
              foundFiles['encoder']!.path.toLowerCase().contains('.int8')) {
            // Prefer non-INT8 version
            print(
              '[sherpa-onxx-sst] _findModelFiles: Found better encoder (non-INT8): $fullPath',
            );
            foundFiles['encoder'] = entity;
          }
        }
        // Find decoder (handles both "decoder.onnx" and "tiny-decoder.onnx" patterns)
        if (name.contains('decoder') && name.endsWith('.onnx')) {
          if (foundFiles['decoder'] == null) {
            foundFiles['decoder'] = entity;
            print(
              '[sherpa-onxx-sst] _findModelFiles: Found decoder candidate: $fullPath',
            );
          } else if (!name.contains('.int8') &&
              foundFiles['decoder']!.path.toLowerCase().contains('.int8')) {
            print(
              '[sherpa-onxx-sst] _findModelFiles: Found better decoder (non-INT8): $fullPath',
            );
            foundFiles['decoder'] = entity;
          }
        }
        // Find joiner (handles both "joiner.onnx" and prefixed patterns)
        // Note: Whisper models don't have joiner, but we check anyway
        if (name.contains('joiner') && name.endsWith('.onnx')) {
          if (foundFiles['joiner'] == null) {
            foundFiles['joiner'] = entity;
            print(
              '[sherpa-onxx-sst] _findModelFiles: Found joiner candidate: $fullPath',
            );
          } else if (!name.contains('.int8') &&
              foundFiles['joiner']!.path.toLowerCase().contains('.int8')) {
            print(
              '[sherpa-onxx-sst] _findModelFiles: Found better joiner (non-INT8): $fullPath',
            );
            foundFiles['joiner'] = entity;
          }
        }
        // Find tokens.txt (handles both "tokens.txt" and "tiny-tokens.txt" patterns)
        if (foundFiles['tokens'] == null &&
            name.contains('tokens') &&
            name.endsWith('.txt')) {
          foundFiles['tokens'] = entity;
          print(
            '[sherpa-onxx-sst] _findModelFiles: Found tokens candidate: $fullPath',
          );
        }
        // Find model.onnx for Paraformer models (prefer non-INT8 version)
        if (name == 'model.onnx' || name == 'model.int8.onnx') {
          if (foundFiles['model'] == null) {
            foundFiles['model'] = entity;
            print(
              '[sherpa-onxx-sst] _findModelFiles: Found model candidate: $fullPath',
            );
          } else if (name == 'model.onnx' &&
              foundFiles['model']!.path.toLowerCase().contains('.int8')) {
            // Prefer non-INT8 version
            print(
              '[sherpa-onxx-sst] _findModelFiles: Found better model (non-INT8): $fullPath',
            );
            foundFiles['model'] = entity;
          }
        }
      }
    }

    print('[sherpa-onxx-sst] _findModelFiles: Searched $fileCount files total');
    print('[sherpa-onxx-sst] _findModelFiles: Results:');
    print(
      '[sherpa-onxx-sst] _findModelFiles: - encoder: ${foundFiles['encoder']?.path ?? "not found"}',
    );
    print(
      '[sherpa-onxx-sst] _findModelFiles: - decoder: ${foundFiles['decoder']?.path ?? "not found"}',
    );
    print(
      '[sherpa-onxx-sst] _findModelFiles: - joiner: ${foundFiles['joiner']?.path ?? "not found"}',
    );
    print(
      '[sherpa-onxx-sst] _findModelFiles: - tokens: ${foundFiles['tokens']?.path ?? "not found"}',
    );
    print(
      '[sherpa-onxx-sst] _findModelFiles: - model: ${foundFiles['model']?.path ?? "not found"}',
    );

    return foundFiles;
  }

  /// Verify model files exist and copy them to expected names if needed
  static Future<void> _verifyAndCopyModelFiles(
    String modelDir, {
    SherpaModelType? model,
    String? modelName,
  }) async {
    print(
      '[sherpa-onxx-sst] _verifyAndCopyModelFiles: Starting verification for modelDir=$modelDir',
    );

    final encoderFile = File('$modelDir/encoder.onnx');
    final decoderFile = File('$modelDir/decoder.onnx');
    final joinerFile = File('$modelDir/joiner.onnx');
    final tokensFile = File('$modelDir/tokens.txt');

    // Check which files exist in root
    final encoderExists = await encoderFile.exists();
    final decoderExists = await decoderFile.exists();
    final joinerExists = await joinerFile.exists();
    final tokensExists = await tokensFile.exists();

    print('[sherpa-onxx-sst] _verifyAndCopyModelFiles: Files in root:');
    print(
      '[sherpa-onxx-sst] _verifyAndCopyModelFiles: - encoder.onnx: $encoderExists',
    );
    print(
      '[sherpa-onxx-sst] _verifyAndCopyModelFiles: - decoder.onnx: $decoderExists',
    );
    print(
      '[sherpa-onxx-sst] _verifyAndCopyModelFiles: - joiner.onnx: $joinerExists',
    );
    print(
      '[sherpa-onxx-sst] _verifyAndCopyModelFiles: - tokens.txt: $tokensExists',
    );

    // Determine if this is a Whisper model (no joiner) or Zipformer model (has joiner)
    // Check both enum and model name string
    final isWhisperModel =
        (model != null &&
            (model == SherpaModelType.whisperTiny ||
                model == SherpaModelType.whisperBase ||
                model == SherpaModelType.whisperSmall)) ||
        (modelName != null && modelName.toLowerCase().contains('whisper'));

    print(
      '[sherpa-onxx-sst] _verifyAndCopyModelFiles: Is Whisper model: $isWhisperModel (model=$model, modelName=$modelName)',
    );

    // For Whisper models, joiner is not required
    final requiredFilesExist =
        encoderExists &&
        decoderExists &&
        tokensExists &&
        (isWhisperModel || joinerExists);

    if (requiredFilesExist) {
      print(
        '[sherpa-onxx-sst] _verifyAndCopyModelFiles: ✓ All required files exist in root, no action needed',
      );
      return;
    }

    print(
      '[sherpa-onxx-sst] _verifyAndCopyModelFiles: Some files missing, searching subdirectories...',
    );
    final foundFiles = await _findModelFiles(modelDir);

    print('[sherpa-onxx-sst] _verifyAndCopyModelFiles: Found files:');
    print(
      '[sherpa-onxx-sst] _verifyAndCopyModelFiles: - encoder: ${foundFiles['encoder']?.path ?? "not found"}',
    );
    print(
      '[sherpa-onxx-sst] _verifyAndCopyModelFiles: - decoder: ${foundFiles['decoder']?.path ?? "not found"}',
    );
    print(
      '[sherpa-onxx-sst] _verifyAndCopyModelFiles: - joiner: ${foundFiles['joiner']?.path ?? "not found"}',
    );
    print(
      '[sherpa-onxx-sst] _verifyAndCopyModelFiles: - tokens: ${foundFiles['tokens']?.path ?? "not found"}',
    );

    // Copy/rename files to expected names in root
    if (foundFiles['encoder'] != null && !encoderExists) {
      print(
        '[sherpa-onxx-sst] _verifyAndCopyModelFiles: Copying encoder from ${foundFiles['encoder']!.path} to ${encoderFile.path}',
      );
      await foundFiles['encoder']!.copy(encoderFile.path);
    }
    if (foundFiles['decoder'] != null && !decoderExists) {
      print(
        '[sherpa-onxx-sst] _verifyAndCopyModelFiles: Copying decoder from ${foundFiles['decoder']!.path} to ${decoderFile.path}',
      );
      await foundFiles['decoder']!.copy(decoderFile.path);
    }
    if (foundFiles['joiner'] != null && !joinerExists && !isWhisperModel) {
      print(
        '[sherpa-onxx-sst] _verifyAndCopyModelFiles: Copying joiner from ${foundFiles['joiner']!.path} to ${joinerFile.path}',
      );
      await foundFiles['joiner']!.copy(joinerFile.path);
    }
    if (foundFiles['tokens'] != null && !tokensExists) {
      print(
        '[sherpa-onxx-sst] _verifyAndCopyModelFiles: Copying tokens from ${foundFiles['tokens']!.path} to ${tokensFile.path}',
      );
      await foundFiles['tokens']!.copy(tokensFile.path);
    }

    print('[sherpa-onxx-sst] _verifyAndCopyModelFiles: Verification complete');
  }

  /// Debug model information - prints comprehensive model status
  ///
  /// [modelName] - The model name to debug
  /// [displayName] - Optional display name for the model
  static Future<void> debugModel(
    String modelName, {
    String? displayName,
  }) async {
    print('\n');
    print('═══════════════════════════════════════════════════════════════');
    print('🔍 SHERPA-ONNX MODEL DEBUG: ${displayName ?? modelName}');
    print('═══════════════════════════════════════════════════════════════');
    print('');

    // 1. Model name
    print('📦 MODEL NAME:');
    print('   Name: $modelName');
    if (displayName != null) {
      print('   Display: $displayName');
    }
    print('');

    // 2. File locations
    print('📁 FILE LOCATIONS:');
    final documentsDir = await getApplicationDocumentsDirectory();
    final modelDir = '${documentsDir.path}/sherpa_onnx_models/$modelName';
    final tempDir = await getTemporaryDirectory();
    final zipFilePath = '${tempDir.path}/$modelName.tar.bz2';
    final downloadUrl =
        'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/$modelName.tar.bz2';

    print('   Model Directory: $modelDir');
    print('   Zip File: $zipFilePath');
    print('   Download URL: $downloadUrl');
    print('');

    // 3. Zip file status
    print('📦 ZIP FILE STATUS:');
    final zipFile = File(zipFilePath);
    final zipExists = await zipFile.exists();
    if (zipExists) {
      final zipSize = await zipFile.length();
      print(
        '   ✓ Zip file exists: ${(zipSize / 1024 / 1024).toStringAsFixed(2)} MB',
      );

      // Check remote size for comparison
      try {
        final remoteSize = await _getRemoteFileSize(
          'https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/$modelName.tar.bz2',
        );
        if (remoteSize != null) {
          final matches = zipSize == remoteSize;
          print(
            '   ${matches ? "✓" : "✗"} Remote size: ${(remoteSize / 1024 / 1024).toStringAsFixed(2)} MB ${matches ? "(matches)" : "(mismatch)"}',
          );
        }
      } catch (e) {
        print('   ⚠ Could not check remote size: $e');
      }
    } else {
      print('   ✗ Zip file does not exist');
    }
    print('');

    // 4. Model directory status
    print('📂 MODEL DIRECTORY STATUS:');
    final modelDirFile = Directory(modelDir);
    final modelDirExists = await modelDirFile.exists();
    if (modelDirExists) {
      print('   ✓ Directory exists');
    } else {
      print('   ✗ Directory does not exist');
      print('');
      print('═══════════════════════════════════════════════════════════════');
      print('');
      return;
    }
    print('');

    // 5. Expected model files with status
    print('✅ EXPECTED MODEL FILES:');
    final encoderFile = File('$modelDir/encoder.onnx');
    final decoderFile = File('$modelDir/decoder.onnx');
    final joinerFile = File('$modelDir/joiner.onnx');
    final tokensFile = File('$modelDir/tokens.txt');

    final encoderExists = await encoderFile.exists();
    final decoderExists = await decoderFile.exists();
    final joinerExists = await joinerFile.exists();
    final tokensExists = await tokensFile.exists();

    final isWhisperModel = modelName.contains('whisper');

    print('   ${encoderExists ? "✓" : "✗"} encoder.onnx: ${encoderFile.path}');
    print('   ${decoderExists ? "✓" : "✗"} decoder.onnx: ${decoderFile.path}');
    if (isWhisperModel) {
      print('   ⚠ joiner.onnx: Not required for Whisper models');
    } else {
      print('   ${joinerExists ? "✓" : "✗"} joiner.onnx: ${joinerFile.path}');
    }
    print('   ${tokensExists ? "✓" : "✗"} tokens.txt: ${tokensFile.path}');
    print('');

    // Check if all required files exist
    final allRequiredExist =
        encoderExists &&
        decoderExists &&
        tokensExists &&
        (isWhisperModel || joinerExists);

    print(
      '   Overall Status: ${allRequiredExist ? "✓ All required files exist" : "✗ Missing required files"}',
    );
    print('');

    // 6. Model files dump (tree structure)
    print('📋 DIRECTORY TREE:');
    try {
      int fileCount = 0;
      int totalSize = 0;

      // Build tree structure
      final tree = <String, Map<String, dynamic>>{};

      await for (final entity in modelDirFile.list(recursive: true)) {
        if (entity is File) {
          fileCount++;
          final size = await entity.length();
          totalSize += size;
          final relativePath = entity.path.replaceFirst('$modelDir/', '');

          // Build tree structure
          final parts = relativePath.split('/');
          Map<String, dynamic> current = tree;

          for (int i = 0; i < parts.length; i++) {
            final part = parts[i];
            final isLast = i == parts.length - 1;

            if (isLast) {
              // File
              if (!current.containsKey('_files')) {
                current['_files'] = <String, int>{};
              }
              (current['_files'] as Map<String, int>)[part] = size;
            } else {
              // Directory
              if (!current.containsKey(part)) {
                current[part] = <String, dynamic>{};
              }
              current = current[part] as Map<String, dynamic>;
            }
          }
        }
      }

      if (fileCount == 0) {
        print('   (No files found)');
      } else {
        print('   Total files: $fileCount');
        print(
          '   Total size: ${(totalSize / 1024 / 1024).toStringAsFixed(2)} MB',
        );
        print('');
        print('   $modelName/');
        _printTree(tree, modelDir, prefix: '   ', isLast: true);
      }
    } catch (e) {
      print('   ⚠ Error listing files: $e');
    }
    print('');

    // 7. Found model files (using _findModelFiles)
    print('🔍 FOUND MODEL FILES (via search):');
    final foundFiles = await _findModelFiles(modelDir);
    print('   Encoder: ${foundFiles['encoder']?.path ?? "not found"}');
    print('   Decoder: ${foundFiles['decoder']?.path ?? "not found"}');
    print('   Joiner: ${foundFiles['joiner']?.path ?? "not found"}');
    print('   Tokens: ${foundFiles['tokens']?.path ?? "not found"}');
    print('');

    // 8. Model type information
    print('ℹ️  MODEL TYPE:');
    print('   Is Whisper Model: $isWhisperModel');
    if (isWhisperModel) {
      print('   Note: Whisper models do not require joiner.onnx');
    }
    print('');

    // 9. Model existence check result
    print('🔎 MODEL EXISTENCE CHECK:');
    final modelExists = await modelExistsByName(modelName);
    print(
      '   Result: ${modelExists ? "✓ Model exists and is ready" : "✗ Model is not ready"}',
    );
    print('');

    print('═══════════════════════════════════════════════════════════════');
    print('');
  }

  /// Print directory tree structure (similar to Unix 'tree' command)
  static void _printTree(
    Map<String, dynamic> tree,
    String basePath, {
    String prefix = '',
    bool isLast = true,
  }) {
    final entries = <String>[];

    // Collect directories and files
    for (final key in tree.keys) {
      if (key != '_files') {
        entries.add(key);
      }
    }

    // Add files at the end
    if (tree.containsKey('_files')) {
      final files = tree['_files'] as Map<String, int>;
      entries.addAll(files.keys);
    }

    // Sort entries (directories first, then files)
    entries.sort((a, b) {
      final aIsDir = tree.containsKey(a) && tree[a] is Map;
      final bIsDir = tree.containsKey(b) && tree[b] is Map;

      if (aIsDir && !bIsDir) return -1;
      if (!aIsDir && bIsDir) return 1;
      return a.compareTo(b);
    });

    for (int i = 0; i < entries.length; i++) {
      final entry = entries[i];
      final isLastEntry = i == entries.length - 1;
      final isDirectory = tree.containsKey(entry) && tree[entry] is Map;

      // Determine prefix characters
      final connector = isLastEntry ? '└── ' : '├── ';
      final nextPrefix = isLastEntry ? '    ' : '│   ';

      if (isDirectory) {
        // Directory
        print('$prefix$connector$entry/');
        _printTree(
          tree[entry] as Map<String, dynamic>,
          '$basePath/$entry',
          prefix: '$prefix$nextPrefix',
          isLast: isLastEntry,
        );
      } else {
        // File
        final files = tree['_files'] as Map<String, int>;
        final size = files[entry]!;
        final sizeStr = size > 1024 * 1024
            ? '${(size / 1024 / 1024).toStringAsFixed(2)} MB'
            : size > 1024
            ? '${(size / 1024).toStringAsFixed(2)} KB'
            : '$size B';
        print('$prefix$connector$entry ($sizeStr)');
      }
    }
  }
}
