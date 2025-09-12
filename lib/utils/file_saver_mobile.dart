import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cross_file/cross_file.dart';

Future<void> saveExcelMobile(List<int> bytes, String fileName) async {
  final directory = await getTemporaryDirectory();
  final path = "${directory.path}/$fileName";
  final file = File(path);
  await file.writeAsBytes(bytes, flush: true);

  // Masih pakai shareXFiles (meski deprecated)
  await Share.shareXFiles(
    [XFile(path)],
    text: "Export Excel: $fileName",
  );
}
