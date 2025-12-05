import 'dart:async';
import 'dart:io';

/// File download helper methods
class FileDownloadHelper {
  /// Download a file from a URI to a local path with resume support
  ///
  /// [uri] - The URI to download from
  /// [filePath] - The local file path to save to
  /// [onProgress] - Optional callback that receives (downloadedBytes, totalBytes)
  ///                totalBytes may be null if content length is unknown
  /// [cancelToken] - Optional cancellation token to cancel the download
  /// [resume] - If true, will resume from existing partial file if it exists
  ///
  /// Throws an exception if the download fails or is cancelled
  static Future<void> downloadFile(
    Uri uri,
    String filePath, {
    void Function(int downloaded, int? total)? onProgress,
    CancellationToken? cancelToken,
    bool resume = true,
  }) async {
    HttpClient? client;
    IOSink? sink;
    File? file;

    try {
      file = File(filePath);
      int existingBytes = 0;
      bool isResuming = false;

      // Check if file exists and we want to resume
      if (resume && await file.exists()) {
        existingBytes = await file.length();
        print('[FileDownloadHelper] downloadFile: Found existing file with $existingBytes bytes, resuming download');
        isResuming = true;
      }

      client = HttpClient();
      final request = await client.getUrl(uri);

      // Add Range header if resuming
      if (isResuming && existingBytes > 0) {
        request.headers.add('Range', 'bytes=$existingBytes-');
        print('[FileDownloadHelper] downloadFile: Adding Range header: bytes=$existingBytes-');
      }

      final response = await request.close();

      // Check for cancellation before processing
      if (cancelToken?.isCancelled ?? false) {
        throw Exception('Download cancelled');
      }

      // Check response status
      // 206 = Partial Content (for resume), 200 = OK (for new download)
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw Exception('Failed to download file: ${response.statusCode}');
      }

      // Open file in append mode if resuming, write mode if new
      if (isResuming) {
        // For append mode, use openWrite with mode append
        sink = file.openWrite(mode: FileMode.append);
      } else {
        // For new file, use openWrite with mode write (truncates)
        sink = file.openWrite();
      }

      int downloaded = existingBytes;
      int? contentLength;

      // Get total content length from headers
      final contentLengthHeader = response.headers.value('content-length');
      final contentRangeHeader = response.headers.value('content-range');

      if (contentRangeHeader != null) {
        // Parse Content-Range header: "bytes 0-999/1000" or "bytes 100-999/1000"
        final rangeMatch = RegExp(r'bytes \d+-\d+/(\d+)').firstMatch(contentRangeHeader);
        if (rangeMatch != null) {
          contentLength = int.parse(rangeMatch.group(1)!);
          print('[FileDownloadHelper] downloadFile: Content-Range header indicates total size: $contentLength bytes');
        }
      } else if (contentLengthHeader != null) {
        contentLength = int.parse(contentLengthHeader);
        if (isResuming) {
          // If resuming, add existing bytes to content length
          contentLength = contentLength + existingBytes;
        }
        print('[FileDownloadHelper] downloadFile: Content-Length header: $contentLength bytes');
      } else {
        // Try to get from response.contentLength
        final responseLength = response.contentLength;
        if (responseLength > 0) {
          contentLength = isResuming ? responseLength + existingBytes : responseLength;
        }
      }

      print('[FileDownloadHelper] downloadFile: Starting download from byte $downloaded, total: ${contentLength ?? "unknown"}');

      await for (final data in response) {
        // Check for cancellation during download
        if (cancelToken?.isCancelled ?? false) {
          await sink.close();
          // Don't delete partial file on cancel if resume is enabled
          if (!resume) {
            await file.delete();
          }
          throw Exception('Download cancelled');
        }

        sink.add(data);
        downloaded += data.length;
        
        if (onProgress != null) {
          onProgress(downloaded, contentLength);
        }
      }
      
      await sink.close();
      client.close();
      
      print('[FileDownloadHelper] downloadFile: Download complete → $filePath (${downloaded} bytes)');
    } catch (e) {
      // Clean up on error or cancellation
      try {
        await sink?.close();
        // Only delete partial file if resume is disabled or it was cancelled/failed early
        if (file != null && await file.exists()) {
          if (!resume || 
              e.toString().contains('cancelled') ||
              e.toString().contains('Failed')) {
            // Only delete if resume is disabled, or if it was cancelled/failed
            // If resume is enabled and it's just an error, keep the partial file
            if (!resume || e.toString().contains('cancelled')) {
              await file.delete();
              print('[FileDownloadHelper] downloadFile: Deleted partial file due to error/cancellation');
            } else {
              final fileSize = await file.length();
              print('[FileDownloadHelper] downloadFile: Keeping partial file for resume: $fileSize bytes');
            }
          }
        }
        client?.close(force: true);
      } catch (_) {
        // Ignore cleanup errors
      }
      if (e.toString().contains('cancelled')) {
        throw Exception('Download cancelled');
      }
      throw Exception('Error downloading file: $e');
    }
  }

  /// Format bytes to human-readable string
  ///
  /// Examples:
  /// - 512 -> "512 B"
  /// - 1536 -> "1.5 KB"
  /// - 1048576 -> "1.0 MB"
  static String formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Get progress text for display
  ///
  /// Returns a formatted string like "1.5 MB / 10.0 MB (15.0%)" or "1.5 MB downloaded..."
  static String getProgressText(int downloadedBytes, int? totalBytes) {
    if (totalBytes != null) {
      final percentage = ((downloadedBytes / totalBytes) * 100).toStringAsFixed(
        1,
      );
      return '${formatBytes(downloadedBytes)} ($percentage%)';
    }
    return '${formatBytes(downloadedBytes)} downloaded...';
  }

  /// Delete a file at the specified path
  ///
  /// [filePath] - The path to the file to delete
  ///
  /// Returns true if the file was deleted, false if it didn't exist
  /// Throws an exception if deletion fails
  static Future<bool> deleteFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      throw Exception('Error deleting file: $e');
    }
  }

  /// Check if a file exists at the specified path
  ///
  /// [filePath] - The path to check
  ///
  /// Returns true if the file exists, false otherwise
  static Future<bool> fileExists(String filePath) async {
    try {
      final file = File(filePath);
      return await file.exists();
    } catch (e) {
      return false;
    }
  }
}

/// Cancellation token for cancelling downloads
class CancellationToken {
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void cancel() {
    _isCancelled = true;
  }

  void reset() {
    _isCancelled = false;
  }
}
