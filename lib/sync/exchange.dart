import 'payload.dart';

/// Decode all parts before applying any records. Compatibility declarations
/// alone do not prove a payload actually has the declared wire shape.
class SyncExchange {
  const SyncExchange(this.state, this.library);
  final SyncPayload state;
  final PeerLibrary library;

  factory SyncExchange.decode(Map<String, dynamic> json) {
    final following = json['following'];
    final lists = json['lists'];
    final library = json['library'];
    if (json['watch'] is! String ||
        following is! Map<String, dynamic> ||
        following['series'] is! List ||
        following['removed'] is! List ||
        lists is! Map<String, dynamic> ||
        lists['entries'] is! List ||
        library is! Map<String, dynamic> ||
        library['revision'] is! String ||
        library['media'] is! List ||
        library['downloads'] is! List) {
      throw const FormatException('The device sent an invalid sync exchange');
    }
    return SyncExchange(
      SyncPayload.fromJson(json),
      PeerLibrary.fromJson(library),
    );
  }
}
