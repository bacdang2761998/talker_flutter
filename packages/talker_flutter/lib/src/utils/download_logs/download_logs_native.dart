import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

Future<void> downloadFile(String logs) async {
  final dir = await getTemporaryDirectory();
  final dirPath = dir.path;
  final fmtDate = DateTime.now().toString().replaceAll(":", " ");
  final file =
      await File('$dirPath/talker_logs_$fmtDate.txt').create(recursive: true);
  await file.writeAsString(logs);
  // vmap: API `Share` cũ có ở mọi bản share_plus 10–13, để app giữ được
  // share_plus 10 (SharePlus.instance chỉ có từ 11).
  // ignore: deprecated_member_use
  await Share.shareXFiles(<XFile>[XFile(file.path)]);
}
