/// A file to include in a multipart form request.
class MultipartFile {
  /// The form field name.
  final String field;

  /// The file content as bytes.
  final List<int> bytes;

  /// The filename, if any.
  final String? filename;

  /// The MIME content type, if any.
  final String? contentType;

  /// Create a multipart file.
  const MultipartFile({
    required this.field,
    required this.bytes,
    this.filename,
    this.contentType,
  });
}
