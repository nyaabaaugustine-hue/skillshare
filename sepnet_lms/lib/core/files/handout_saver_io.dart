import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Writes a bundled handout into the app's documents directory.
///
/// Android and iOS do not let an app drop a file straight into the user's
/// Downloads folder, so the handout is written where the app owns storage and
/// the returned sentence names the full path so the learner can find it again.
Future<String> saveHandout({
  required Uint8List bytes,
  required String fileName,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File(p.join(dir.path, fileName));
  await file.writeAsBytes(bytes, flush: true);
  return 'Saved to ${file.path}';
}
