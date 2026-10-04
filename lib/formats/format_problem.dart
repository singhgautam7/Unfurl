/// Why a file Unfurl recognises still can't be read (board 6, V3 error
/// states): protected by DRM, a format variant it doesn't support, or damaged.
enum ProblemKind { drm, unsupported, damaged }

class FormatProblem implements Exception {
  const FormatProblem(this.kind, this.detail, {this.readable});

  final ProblemKind kind;

  /// The cause for the mono detail box: "Kindle DRM", "Topaz (AZW1)".
  final String detail;

  /// A damaged archive: how many pages could still be read, of how many.
  final (int, int)? readable;

  @override
  String toString() => 'FormatProblem($kind, $detail)';
}
