# Google Drive sync setup (Online Mode)

The sync engine is tested against an in-memory remote. The real `DriveRemote`
(`lib/sync/drive_remote.dart`) is compiled and analysed but has NOT been run
against Google because it needs your OAuth client:

1. Google Cloud Console -> new project -> enable "Google Drive API".
2. OAuth consent screen; add scope `https://www.googleapis.com/auth/drive.appdata`.
3. Create OAuth clients: Android (package `com.denovo.cash_buddy` + SHA-1) and iOS
   (bundle id). Put the iOS client id / reversed id in `ios/Runner/Info.plist`
   (`GIDClientID`, URL scheme) and the Android `google-services`/client config.
4. Test on two devices: add data on A, sign in on B, confirm it merges.
