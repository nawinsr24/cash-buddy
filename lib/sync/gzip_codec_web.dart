import 'package:archive/archive.dart';

List<int> gzipEncode(List<int> bytes) => GZipEncoder().encodeBytes(bytes);
List<int> gzipDecode(List<int> bytes) => GZipDecoder().decodeBytes(bytes);
