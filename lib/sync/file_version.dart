import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// Identifies a served file incarnation; replacing or modifying it invalidates
/// offers and partial copies, even when the replacement has the same size.
String fileVersion(File file) {
  return fileVersionFromStat(file, file.statSync());
}

String fileVersionFromStat(File file, FileStat stat) {
  return sha256
      .convert(
        utf8.encode(
          '${file.absolute.path}:${stat.size}:${stat.modified.microsecondsSinceEpoch}:${stat.changed.microsecondsSinceEpoch}',
        ),
      )
      .toString();
}
