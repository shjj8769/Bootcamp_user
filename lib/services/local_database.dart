/// ERD에 정의된 쇼핑몰 로컬 SQLite 데이터베이스.
///
/// 화면에서는 이 파일만 import하여 [LocalDatabase.instance]를 사용한다.
/// 예: final db = await LocalDatabase.instance.database;
///     await LocalDatabase.instance.insertRecord(
///       LocalDatabase.customer,
///       {'mail': email, 'size': selectedSize},
///     );
///
/// 임의의 초기/샘플 데이터는 삽입하지 않는다. 테이블과 인덱스만 생성한다.
library;

import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';

/// DB 생성, ERD 스키마 관리, 공통 CRUD를 한 곳에서 제공한다.
class LocalDatabase {
  LocalDatabase._();

  /// 앱 전체에서 동일한 연결을 재사용하는 싱글턴.
  static final LocalDatabase instance = LocalDatabase._();

  static const String _databaseName = 'shopping_local.db';
  static const int _databaseVersion = 1;

  // ERD의 엔티티 및 관계 테이블 이름을 화면 코드에서 재사용한다.
  static const String package = 'package';
  static const String coupon = 'coupon';
  static const String customer = 'customer';
  static const String paymentMethod = 'payment_method';
  static const String wishlist = 'wishlist';
  static const String recentlyViewedProduct = 'recently_viewed_product';
  static const String choice = 'choice';
  static const String search = 'search';

  /// 허용된 테이블만 CRUD 메서드에 전달할 수 있게 제한한다.
  static const Set<String> _tables = {
    package,
    coupon,
    customer,
    paymentMethod,
    wishlist,
    recentlyViewedProduct,
    choice,
    search,
  };

  Database? _database;

  /// 아직 열리지 않았다면 DB를 생성하고 스키마를 준비한다.
  Future<Database> get database async {
    final opened = _database;
    if (opened != null && opened.isOpen) return opened;

    _database = await _openDatabase();
    return _database!;
  }

  Future<Database> _openDatabase() async {
    final directory = await getDatabasesPath();
    final filePath = path.join(directory, _databaseName);

    return openDatabase(
      filePath,
      version: _databaseVersion,
      onConfigure: (db) async {
        // SQLite는 기본 설정에서 FK 검사가 꺼져 있을 수 있으므로 명시한다.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await _createSchema(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        // 향후 스키마 변경은 버전별 ALTER TABLE 마이그레이션으로 추가한다.
        // 기존 데이터를 지우거나 임의로 다시 시드하지 않는다.
        if (oldVersion < 2 && newVersion >= 2) {
          // 다음 스키마 버전에서 필요한 변경 사항을 여기에 작성한다.
        }
      },
    );
  }

  /// ERD의 6개 엔티티와 2개 관계를 생성한다.
  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE "$package" (
        option_code TEXT PRIMARY KEY NOT NULL,
        size TEXT NOT NULL,
        color TEXT NOT NULL,
        product TEXT NOT NULL,
        quantity INTEGER NOT NULL CHECK (quantity >= 0)
      )
    ''');

    await db.execute('''
      CREATE TABLE "$coupon" (
        c_seq INTEGER PRIMARY KEY AUTOINCREMENT,
        c_code TEXT NOT NULL,
        issuer TEXT NOT NULL,
        discount_rate REAL NOT NULL CHECK (discount_rate >= 0),
        exp TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE "$customer" (
        mail TEXT PRIMARY KEY NOT NULL,
        size TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE "$paymentMethod" (
        payment_id TEXT PRIMARY KEY NOT NULL,
        option TEXT NOT NULL CHECK (option IN ('01', '02', '03'))
      )
    ''');

    // ERD상 wishlist 엔티티의 속성은 seq와 product_id이다.
    // 상품 엔티티가 없으므로 product_id를 임의의 상품 마스터 FK로 만들지 않는다.
    await db.execute('''
      CREATE TABLE "$wishlist" (
        seq INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE "$recentlyViewedProduct" (
        view_seq INTEGER PRIMARY KEY AUTOINCREMENT,
        product_id TEXT NOT NULL,
        view_date TEXT NOT NULL
      )
    ''');

    // choice 관계는 네 엔티티의 PK를 복합 FK/PK로 사용해 중복 연결을 막는다.
    await db.execute('''
      CREATE TABLE "$choice" (
        option_code TEXT NOT NULL,
        c_seq INTEGER NOT NULL,
        mail TEXT NOT NULL,
        payment_id TEXT NOT NULL,
        PRIMARY KEY (option_code, c_seq, mail, payment_id),
        FOREIGN KEY (option_code) REFERENCES "$package" (option_code)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY (c_seq) REFERENCES "$coupon" (c_seq)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY (mail) REFERENCES "$customer" (mail)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY (payment_id) REFERENCES "$paymentMethod" (payment_id)
          ON UPDATE CASCADE ON DELETE CASCADE
      )
    ''');

    // search 관계는 고객, wishlist, 최근 본 상품을 함께 연결한다.
    // 별도의 관계 PK는 만들지 않고 세 엔티티 PK 조합으로 관계를 식별한다.
    await db.execute('''
      CREATE TABLE "$search" (
        mail TEXT NOT NULL,
        seq INTEGER NOT NULL,
        view_seq INTEGER NOT NULL,
        search_count INTEGER NOT NULL DEFAULT 0 CHECK (search_count >= 0),
        PRIMARY KEY (mail, seq, view_seq),
        FOREIGN KEY (mail) REFERENCES "$customer" (mail)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY (seq) REFERENCES "$wishlist" (seq)
          ON UPDATE CASCADE ON DELETE CASCADE,
        FOREIGN KEY (view_seq) REFERENCES "$recentlyViewedProduct" (view_seq)
          ON UPDATE CASCADE ON DELETE CASCADE
      )
    ''');
  }

  /// 테이블 이름을 allowlist로 확인하여 SQL 식별자 삽입을 차단한다.
  void _requireTable(String table) {
    if (!_tables.contains(table)) {
      throw ArgumentError.value(table, 'table', 'ERD에 없는 테이블입니다.');
    }
  }

  /// 한 행을 추가한다. 컬럼 값은 바인딩되어 SQL 문자열로 합쳐지지 않는다.
  Future<int> insertRecord(
    String table,
    Map<String, Object?> values, {
    ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort,
  }) async {
    _requireTable(table);
    if (values.isEmpty) throw ArgumentError('추가할 값이 비어 있습니다.');
    return (await database).insert(
      table,
      values,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  /// 조건에 맞는 행들을 조회한다. whereArgs에 값을 전달해 SQL injection을 방지한다.
  Future<List<Map<String, Object?>>> queryRecords(
    String table, {
    String? where,
    List<Object?>? whereArgs,
    String? orderBy,
    int? limit,
    int? offset,
  }) async {
    _requireTable(table);
    return (await database).query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
      offset: offset,
    );
  }

  /// 조건에 맞는 행의 컬럼 값을 갱신한다.
  Future<int> updateRecords(
    String table,
    Map<String, Object?> values, {
    required String where,
    required List<Object?> whereArgs,
    ConflictAlgorithm conflictAlgorithm = ConflictAlgorithm.abort,
  }) async {
    _requireTable(table);
    if (values.isEmpty) throw ArgumentError('갱신할 값이 비어 있습니다.');
    return (await database).update(
      table,
      values,
      where: where,
      whereArgs: whereArgs,
      conflictAlgorithm: conflictAlgorithm,
    );
  }

  /// 조건에 맞는 행을 삭제한다. 전체 삭제가 필요하면 별도 호출을 명시한다.
  Future<int> deleteRecords(
    String table, {
    required String where,
    required List<Object?> whereArgs,
  }) async {
    _requireTable(table);
    return (await database).delete(table, where: where, whereArgs: whereArgs);
  }

  /// choice 관계를 네 엔티티의 PK로 연결한다.
  Future<int> addChoice({
    required String optionCode,
    required int couponSeq,
    required String mail,
    required String paymentId,
  }) => insertRecord(choice, {
    'option_code': optionCode,
    'c_seq': couponSeq,
    'mail': mail,
    'payment_id': paymentId,
  });

  /// 고객의 wishlist 항목을 추가한다.
  Future<int> addWishlistItem({required String productId}) =>
      insertRecord(wishlist, {'product_id': productId});

  /// 최근 본 상품을 추가한다. 호출자가 기록 시각을 전달한다.
  Future<int> addRecentlyViewedProduct({
    required String productId,
    required DateTime viewedAt,
  }) => insertRecord(recentlyViewedProduct, {
    'product_id': productId,
    'view_date': viewedAt.toIso8601String(),
  });

  /// ERD의 고객-wishlist-최근본상품 관계를 기록/갱신한다.
  Future<void> recordSearch({
    required String mail,
    required int wishlistSeq,
    required int viewSeq,
  }) async {
    final db = await database;
    await db.transaction((txn) async {
      final matches = await txn.query(
        search,
        columns: ['search_count'],
        where: 'mail = ? AND seq = ? AND view_seq = ?',
        whereArgs: [mail, wishlistSeq, viewSeq],
        limit: 1,
      );

      if (matches.isEmpty) {
        await txn.insert(search, {
          'mail': mail,
          'seq': wishlistSeq,
          'view_seq': viewSeq,
          'search_count': 1,
        });
      } else {
        final currentCount = matches.first['search_count']! as int;
        await txn.update(
          search,
          {'search_count': currentCount + 1},
          where: 'mail = ? AND seq = ? AND view_seq = ?',
          whereArgs: [mail, wishlistSeq, viewSeq],
        );
      }
    });
  }

  /// 앱 종료/테스트에서 연결을 명시적으로 닫는다.
  Future<void> close() async {
    final opened = _database;
    _database = null;
    if (opened != null && opened.isOpen) await opened.close();
  }
}
