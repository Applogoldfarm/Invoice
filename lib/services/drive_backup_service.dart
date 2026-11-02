import 'dart:async';
import 'dart:convert';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'backup_service.dart';
import 'db_helper.dart';

/// Your Web application client ID from Google Cloud Console.
const String _webClientId =
    '574151063793-vi1ek0jnnc4cbfsa27uuiucek32d0abf.apps.googleusercontent.com';

/// The backup goes in Drive's hidden "app data" folder, so it never
/// clutters your Drive and only this app can see it.
const List<String> _scopes = [
  'https://www.googleapis.com/auth/drive.appdata',
];

const String _fileName = 'invoice_backup.json';

class _AuthClient extends http.BaseClient {
  final String token;
  final String email;
  final http.Client _inner = http.Client();

  _AuthClient(this.token, this.email);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $token';
    return _inner.send(request);
  }

  @override
  void close() {
    _inner.close();
    super.close();
  }
}

class DriveBackupService {
  static bool _initialised = false;
  static Timer? _timer;
  static bool _running = false;

  static Future<void> _init() async {
    if (_initialised) return;
    await GoogleSignIn.instance.initialize(serverClientId: _webClientId);
    _initialised = true;
  }

  /// Connects to Google Drive. In silent mode it never shows any sign-in
  /// screen: if it cannot connect quietly, it returns null.
  static Future<_AuthClient?> _connect({bool silent = false}) async {
    await _init();
    final signIn = GoogleSignIn.instance;

    GoogleSignInAccount? account =
        await signIn.attemptLightweightAuthentication();
    if (account == null) {
      if (silent) return null;
      account = await signIn.authenticate(scopeHint: _scopes);
    }

    var auth = await account.authorizationClient.authorizationForScopes(_scopes);
    if (auth == null) {
      if (silent) return null;
      auth = await account.authorizationClient.authorizeScopes(_scopes);
    }

    return _AuthClient(auth.accessToken, account.email);
  }

  static Future<drive.File?> _findBackup(drive.DriveApi api) async {
    final res = await api.files.list(
      spaces: 'appDataFolder',
      q: "name = '$_fileName'",
      $fields: 'files(id,name,modifiedTime)',
      pageSize: 10,
    );
    final files = res.files ?? [];
    return files.isEmpty ? null : files.first;
  }

  static Future<void> _upload(_AuthClient client) async {
    final api = drive.DriveApi(client);
    final bytes = utf8.encode(await BackupService.buildBackupJson());
    final media = drive.Media(Stream.value(bytes), bytes.length);

    final existing = await _findBackup(api);
    if (existing?.id != null) {
      await api.files.update(drive.File(), existing!.id!, uploadMedia: media);
    } else {
      await api.files.create(
        drive.File()
          ..name = _fileName
          ..parents = ['appDataFolder'],
        uploadMedia: media,
      );
    }

    final db = DbHelper.instance;
    await db.setSetting('drive_backup_last', DateTime.now().toIso8601String());
    await db.setSetting('drive_backup_error', '');
  }

  /// Uploads the backup to Google Drive. Returns the Google account email.
  static Future<String> backupNow() async {
    final client = (await _connect())!;
    try {
      await _upload(client);
      return client.email;
    } finally {
      client.close();
    }
  }

  /// Called whenever invoices change. If automatic backup is switched on,
  /// uploads a backup a few seconds later (several changes in a row are
  /// combined into one upload).
  static void scheduleAutoBackup() {
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 5), _runAuto);
  }

  static Future<void> _runAuto() async {
    final db = DbHelper.instance;
    if (await db.getSetting('auto_backup') != '1') return;
    if (_running) {
      scheduleAutoBackup();
      return;
    }
    _running = true;
    _AuthClient? client;
    try {
      client = await _connect(silent: true);
      if (client == null) {
        await db.setSetting(
          'drive_backup_error',
          'Automatic backup could not sign in. Open Settings and tap Back up.',
        );
        return;
      }
      await _upload(client);
    } catch (_) {
      await db.setSetting(
        'drive_backup_error',
        'The last automatic backup failed. It will try again after your next change.',
      );
    } finally {
      client?.close();
      _running = false;
    }
  }

  /// Downloads the backup from Google Drive and replaces all current data.
  /// Returns the number of invoices restored, or null if no backup exists.
  static Future<int?> restoreNow() async {
    final client = (await _connect())!;
    try {
      final api = drive.DriveApi(client);
      final file = await _findBackup(api);
      if (file?.id == null) return null;

      final media = await api.files.get(
        file!.id!,
        downloadOptions: drive.DownloadOptions.fullMedia,
      ) as drive.Media;

      final bytes = <int>[];
      await for (final chunk in media.stream) {
        bytes.addAll(chunk);
      }
      return BackupService.restoreFromJson(utf8.decode(bytes));
    } finally {
      client.close();
    }
  }
}
