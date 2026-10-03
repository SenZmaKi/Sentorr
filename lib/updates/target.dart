import 'dart:ffi';
import 'dart:io';

class UpdateTarget {
  final String platform;
  final String architecture;

  const UpdateTarget(this.platform, this.architecture);

  static UpdateTarget get current {
    final platform = Platform.isAndroid
        ? 'android'
        : Platform.isWindows
        ? 'windows'
        : Platform.isMacOS
        ? 'macos'
        : Platform.isLinux
        ? 'linux'
        : 'unsupported';
    final abi = Abi.current().toString().split('.').last.toLowerCase();
    final architecture = abi.contains('arm64')
        ? 'arm64'
        : abi.contains('arm')
        ? 'arm'
        : abi.contains('ia32')
        ? 'x86'
        : 'x64';
    return UpdateTarget(platform, architecture);
  }
}
