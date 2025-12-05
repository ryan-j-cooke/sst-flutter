import 'dart:async';
import 'dart:io';

/// File download helper methods
class FileDownloadHelper {
  /// Download a file from a URI to a local path
  ///
  /// [uri] - The URI to download from
  /// [filePath] - The local file path to save to
  /// [onProgress] - Optional callback that receives (downloadedBytes, totalBytes)
  ///                totalBytes may be null if content length is unknown
  /// [cancelToken] - Optional cancellation token to cancel the download
  ///
  /// Throws an exception if the download fails or is cancelled
  static Future<void> downloadFile(
    Uri uri,
    String filePath, {
    void Function(int downloaded, int? total)? onProgress,
    CancellationToken? cancelToken,
  }) async {
    HttpClient? client;
    IOSink? sink;
    File? file;

    try {
      client = HttpClient();
      final request = await client.getUrl(uri);
      final response = await request.close();

      // Check for cancellation before processing
      if (cancelToken?.isCancelled ?? false) {
        throw Exception('Download cancelled');
      }

      if (response.statusCode != 200) {
        throw Exception('Failed to download file: ${response.statusCode}');
      }

      file = File(filePath);
      sink = file.openWrite();

      int downloaded = 0;
      final contentLength = response.contentLength;

      await for (final data in response) {
        // Check for cancellation during download
        if (cancelToken?.isCancelled ?? false) {
          await sink.close();
          await file.delete(); // Delete partial file
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
    } catch (e) {
      // Clean up on error or cancellation
      try {
        await sink?.close();
        if (file != null && await file.exists()) {
          // Only delete if it was cancelled or failed early
          if (e.toString().contains('cancelled') ||
              e.toString().contains('Failed')) {
            await file.delete();
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
