import 'package:dio/dio.dart';

import '../shared/persistence/app_paths.dart';
import '../shared/persistence/json_file_store.dart';
import '../shared/signed_envelope.dart';

import 'dart:convert';

import 'models.dart';

class UpdateManifestRepository {
  static const manifestUri = String.fromEnvironment(
    'UPDATE_MANIFEST_URL',
    defaultValue: 'https://senzmaki.github.io/Sentorr/update-manifest.json',
  );
  const UpdateManifestRepository({required this.paths, required this.dio});
  final AppPaths paths;
  final Dio dio;
  Future<UpdateManifest?> loadCached() async {
    final envelope = await JsonFileStore(paths.updateManifestFile).read();
    return envelope == null ? null : _decode(jsonEncode(envelope));
  }

  Future<UpdateManifest> _decode(String envelope) async =>
      UpdateManifest.fromJson(
        await decodeSignedJsonEnvelope(
          envelope,
          publicKeyBase64: updateManifestPublicKeyBase64,
        ),
      );
  Future<UpdateManifest> fetch() async {
    final response = await dio.get<String>(
      manifestUri,
      options: Options(
        responseType: ResponseType.plain,
        headers: {'Cache-Control': 'no-cache'},
        validateStatus: (s) => s == 200,
      ),
    );
    final envelope = response.data;
    if (envelope == null) throw const FormatException('Empty update manifest');
    final manifest = await _decode(envelope);
    await JsonFileStore(paths.updateManifestFile)
        .write(jsonDecode(envelope) as Map<String, dynamic>);
    return manifest;
  }
}
