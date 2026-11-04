import 'dart:io' show gzip;

List<int> gzipEncode(List<int> bytes) => gzip.encode(bytes);
List<int> gzipDecode(List<int> bytes) => gzip.decode(bytes);
