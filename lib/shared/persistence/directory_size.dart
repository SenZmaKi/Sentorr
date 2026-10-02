import 'dart:io';

/// Total bytes of the files under [directory]; zero when it is missing.
Future<int> directorySize(Directory directory) async {
  if (!await directory.exists()) return 0;
  var total = 0;
  try {
    await for (final entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        try {
          total += await entity.length();
        } on FileSystemException {
          // Files may disappear while counting.
        }
      }
    }
  } on FileSystemException {
    // The directory itself went away or became unreadable mid-count.
  }
  return total;
}
