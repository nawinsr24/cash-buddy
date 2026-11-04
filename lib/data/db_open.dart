// Picks the right SQLite backend: native file on mobile, WASM in the browser.
export 'db_open_native.dart' if (dart.library.js_interop) 'db_open_web.dart';
