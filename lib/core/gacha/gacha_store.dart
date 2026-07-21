import 'dart:io';
import 'dart:math';

import 'package:sqlite3/sqlite3.dart';

import '../system/platform_services.dart';
import 'gacha_card.dart';

class GachaSnapshot {
  const GachaSnapshot({
    required this.ownedCounts,
    required this.lastDrawDate,
    required this.bonusDraws,
    required this.pitySinceSsr,
  });

  final Map<String, int> ownedCounts;
  final String? lastDrawDate;
  final int bonusDraws;
  final int pitySinceSsr;
}

class GachaStore {
  GachaStore({Directory? storageDirectory})
    : _storageDirectory =
          storageDirectory ?? PlatformServices.instance.paths.appDataDirectory;

  final Directory _storageDirectory;
  Database? _database;

  Database get _db => _database ??= _open(_storageDirectory.path);

  static Database _open(String directoryPath) {
    final directory = Directory(directoryPath);
    if (!directory.existsSync()) {
      directory.createSync(recursive: true);
    }
    final database = sqlite3.open(
      '$directoryPath${Platform.pathSeparator}moviehub.db',
    );
    database.execute('PRAGMA journal_mode = WAL;');
    database.execute('PRAGMA busy_timeout = 5000;');
    database.execute('''
      CREATE TABLE IF NOT EXISTS gacha_owned_cards (
        card_id TEXT PRIMARY KEY,
        count INTEGER NOT NULL,
        first_drawn_at TEXT NOT NULL,
        last_drawn_at TEXT NOT NULL
      );
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS gacha_draws (
        id TEXT PRIMARY KEY,
        card_id TEXT NOT NULL,
        draw_date TEXT NOT NULL,
        drawn_at TEXT NOT NULL
      );
    ''');
    database.execute('''
      CREATE TABLE IF NOT EXISTS gacha_state (
        id INTEGER PRIMARY KEY CHECK (id = 1),
        bonus_draws INTEGER NOT NULL,
        pity_since_ssr INTEGER NOT NULL
      );
    ''');
    database.execute(
      'INSERT OR IGNORE INTO gacha_state (id, bonus_draws, pity_since_ssr) VALUES (1, 0, 0)',
    );
    return database;
  }

  GachaSnapshot load() {
    final ownedCounts = <String, int>{};
    for (final row in _db.select(
      'SELECT card_id, count FROM gacha_owned_cards',
    )) {
      ownedCounts[row['card_id'] as String] = row['count'] as int;
    }
    final lastRows = _db.select(
      'SELECT draw_date FROM gacha_draws ORDER BY drawn_at DESC LIMIT 1',
    );
    final state = _db
        .select(
          'SELECT bonus_draws, pity_since_ssr FROM gacha_state WHERE id = 1',
        )
        .first;
    return GachaSnapshot(
      ownedCounts: ownedCounts,
      lastDrawDate: lastRows.isEmpty
          ? null
          : lastRows.first['draw_date'] as String,
      bonusDraws: state['bonus_draws'] as int,
      pitySinceSsr: state['pity_since_ssr'] as int,
    );
  }

  bool hasDrawnOn(String drawDate) {
    final rows = _db.select(
      'SELECT 1 FROM gacha_draws WHERE draw_date = ? LIMIT 1',
      [drawDate],
    );
    return rows.isNotEmpty;
  }

  bool recordDraw(
    GachaCard card,
    DateTime now, {
    required bool consumeBonusDraw,
  }) {
    final drawDate = dateKey(now);
    final drawnAt = now.toIso8601String();
    final id =
        '${drawDate}_${now.microsecondsSinceEpoch}_${Random().nextInt(99999)}';
    var isNew = false;

    _db.execute('BEGIN');
    try {
      if (consumeBonusDraw) {
        final state = _db
            .select('SELECT bonus_draws FROM gacha_state WHERE id = 1')
            .first;
        final bonusDraws = state['bonus_draws'] as int;
        if (bonusDraws <= 0) {
          throw StateError('没有可用的额外抽卡次数。');
        }
        _db.execute(
          'UPDATE gacha_state SET bonus_draws = bonus_draws - 1 WHERE id = 1',
        );
      }
      final existing = _db.select(
        'SELECT count FROM gacha_owned_cards WHERE card_id = ?',
        [card.id],
      );
      if (existing.isEmpty) {
        isNew = true;
        _db.execute(
          '''
          INSERT INTO gacha_owned_cards
            (card_id, count, first_drawn_at, last_drawn_at)
          VALUES (?, 1, ?, ?)
          ''',
          [card.id, drawnAt, drawnAt],
        );
      } else {
        _db.execute(
          '''
          UPDATE gacha_owned_cards
          SET count = count + 1, last_drawn_at = ?
          WHERE card_id = ?
          ''',
          [drawnAt, card.id],
        );
      }
      _db.execute(
        'INSERT INTO gacha_draws (id, card_id, draw_date, drawn_at) VALUES (?, ?, ?, ?)',
        [id, card.id, drawDate, drawnAt],
      );
      _db.execute('UPDATE gacha_state SET pity_since_ssr = ? WHERE id = 1', [
        card.rarity == GachaRarity.ssr ? 0 : load().pitySinceSsr + 1,
      ]);
      _db.execute('COMMIT');
    } catch (_) {
      _db.execute('ROLLBACK');
      rethrow;
    }

    return isNew;
  }

  void addBonusDraws(int count) {
    if (count <= 0) {
      return;
    }
    _db.execute(
      'UPDATE gacha_state SET bonus_draws = bonus_draws + ? WHERE id = 1',
      [count],
    );
  }

  static String todayKey() => dateKey(DateTime.now());

  static String dateKey(DateTime value) {
    final local = value.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year}-$month-$day';
  }

  void dispose() {
    _database?.dispose();
    _database = null;
  }
}
