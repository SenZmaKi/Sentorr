String? validateDeviceName(String value) =>
    value.trim().isEmpty ? 'Enter a device name.' : null;

String? validateProxyHost(String value) {
  final host = value.contains(':') && !value.startsWith('[')
      ? '[$value]'
      : value;
  final uri = Uri.tryParse('http://$host');
  return value.isEmpty ||
          RegExp(r'\s').hasMatch(value) ||
          uri == null ||
          uri.host.isEmpty ||
          uri.hasPort ||
          uri.userInfo.isNotEmpty ||
          uri.path.isNotEmpty ||
          uri.hasQuery ||
          uri.hasFragment
      ? 'Enter a hostname or IP address without a port or URL.'
      : null;
}
