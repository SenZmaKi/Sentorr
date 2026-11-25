import 'package:disk_space_info/disk_space_info.dart';

/// Free space on [path]'s volume, read natively on every platform; null
/// when it can't be read. What an unprivileged process may write, so it
/// errs low.
Future<int?> freeBytes(String path) async =>
    (await DiskSpaceInfo.query(path))?.freeBytes;
