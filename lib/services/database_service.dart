// import 'dart:ffi';
// import 'package:sqflite_sqlcipher/sqflite.dart' as sqlcipher;
import 'dart:collection';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import 'package:logger/logger.dart';
import 'package:web_admin/helpers/database_path_helper.dart';

/// Class to manage queries and DB structure
///
/// parameters:
/// * [sqlLiteService] create instance sqlilite.
/// * [sqlService] factory to create the structure of the DB.
/// * [Database]  file to store the data.
/// * [dbName]  DB name
/// * [currentVersion]  manage the version of the production DB this is useful when if neccessary update fields or add new tables IMPORTANT!.
///
/// Methods:
/// * [database] init the DB object and structure
/// * [_getDbPath] set the store location
/// * [_initDatabase] init DB
/// * [_onCreate] create tables
/// * [_onUpgrade] insert new updates into the production DB, acording the revision of the DB

class SqlLiteService {
  static final SqlLiteService _instance = SqlLiteService._internal();
  factory SqlLiteService() => _instance;
  static sqflite.Database? _database;
  static const dbName = 'posdb.db';
  final logger = Logger(printer: PrettyPrinter());

  /// if the version change please
  /// pleae refer to _onUpgrade to see the index of changes
  /// if you update and add the new tables on _createTables to keep
  /// updated the schema for new installation
  /// ##################################
  static const currentVersion = 7;

  /// #################################

  SqlLiteService._internal();

  Future<sqflite.Database> get database async {
    if (_database != null) return _database!;

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi; // Important! start the factory
      _database = await _initDatabase();
    } else {
      _database = await _initDatabase();
    }
    return _database!;
  }

  Future<String> _getDbPath() async {
    if (Platform.isAndroid || Platform.isIOS) {
      final dbBase = await sqflite.getDatabasesPath();
      return resolveDatabasePath(
        isMobile: true,
        dbName: dbName,
        mobileDatabasesPath: dbBase,
        executableDir: '',
      );
    }

    final executableDir = File(Platform.resolvedExecutable).parent.path;
    return resolveDatabasePath(
      isMobile: false,
      dbName: dbName,
      executableDir: executableDir,
    );
  }

  Future<sqflite.Database> _initDatabase() async {
    String path = await _getDbPath();

    // check if the db exits
    if (await File(path).exists()) {
      //logger.d('Deleting existing database at path: $path');
      //await File(path).delete();
    }

    // logger.d('Initializing database at path: $path');
    return await sqflite.openDatabase(
      path,
      version: currentVersion, //increment the version per every change
      onCreate: _onCreate,
      onUpgrade: _onUpgrade, //use this method to update tables or add new ones
      // password: 'XirjaPOS**',
      // onOpen: (db) {// print('Database opened');},
    );
  }

  Future<void> _onCreate(sqflite.Database db, int version) async {
    await _createTables(db, currentVersion);
  }

  Future<void> _createTables(sqflite.Database db, int version) async {
    // print('Creating database tables...');
    await db.execute('''
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,      
        user_personnel_id TEXT,        
        user_group TEXT,
        user_first_name TEXT,
        user_last_name TEXT,
        user_img TEXT,
        user_email TEXT,
        UNIQUE(user_personnel_id)
      );
      CREATE INDEX idx_user ON users(user_personnel_id);      
    ''');

    await db.execute('''
      CREATE TABLE loy_custx (
        id INTEGER PRIMARY KEY AUTOINCREMENT,      
        loy_custx_id TEXT,
        loy_custx_card_num TEXT,
        loy_custx_type TEXT,        
        loy_custx_first_name TEXT,
        loy_custx_last_name TEXT,
        loy_custx_name TEXT,
        loy_custx_email TEXT,
        loy_custx_address TEXT,
        loy_custx_city TEXT,
        loy_custx_mobile TEXT,
        loy_custx_balance REAL,
        loy_custx_points INTEGER,
        loy_custx_scheme TEXT,
        loy_custx_group TEXT,
        loy_custx_frozen INTEGER,
        loy_custx_sync_frappe TEXT,         
        UNIQUE(loy_custx_id)
      );
      CREATE INDEX idx_custx ON loy_custx(loy_custx_id);      
    ''');

    await db.execute('''
      CREATE TABLE loy_custx_txn (
        id INTEGER PRIMARY KEY AUTOINCREMENT,      
        loy_custx_txn_user_id TEXT,
        loy_custx_txn_sale_num TEXT,        
        loy_custx_txn_pts_used INTEGER,
        loy_custx_txn_ptx_earned INTEGER,        
        loy_custx_txn_amt_disc REAL,        
        loy_custx_txn_sync_frappe TEXT,
        UNIQUE(loy_custx_txn_user_id)
      );
      CREATE INDEX idx_custx_txn ON loy_custx_txn(loy_custx_txn_user_id);      
    ''');

    await db.execute('''
      CREATE TABLE stores (
        id INTEGER PRIMARY KEY AUTOINCREMENT,      
        stores_id TEXT,
        stores_name TEXT,
        stores_address TEXT,
        stores_country TEXT,
        stores_phone_num TEXT,
        stores_registration_num TEXT,
        stores_channel_type TEXT,
        stores_legal_entity TEXT,
        stores_vat_group TEXT,
        stores_default_customer TEXT,
        stores_contact_address TEXT,
        stores_contact  TEXT,
        stores_invent_id TEXT,
        stores_invent_location TEXT,
        stores_bcrs_code,
        stores_opening_hours,
        stores_loyalty_enabled INTEGER DEFAULT 1,
        stores_loyalty_allow_earn INTEGER DEFAULT 1,
        stores_loyalty_allow_redeem INTEGER DEFAULT 1,
        stores_loyalty_show_customer_ui INTEGER DEFAULT 1,
        stores_loyalty_show_points_ui INTEGER DEFAULT 1,
        stores_loyalty_show_receipt_details INTEGER DEFAULT 1
      );
      CREATE INDEX idx_stores ON stores(stores_id);      
    ''');

    //stores payment methods available
    await db.execute('''
      CREATE TABLE stores_py_ava (
        id INTEGER PRIMARY KEY AUTOINCREMENT,      
        stores_py_id TEXT,                
        stores_py_ava_mthd_id TEXT        
      );      
    ''');

    await db.execute('''
      CREATE TABLE registers (
        id INTEGER PRIMARY KEY AUTOINCREMENT,      
        registers_id,
        registers_name TEXT,
        registers_store_id TEXT        
      );
      CREATE INDEX idx_registers ON registers(registers_id);      
    ''');

    await db.execute('''
      CREATE TABLE items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        item_id TEXT,
        item_img TEXT,
        item_store TEXT,
        item_brand TEXT,
        item_description TEXT,
        item_barcode TEXT,
        item_name TEXT,
        item_qty NUMBER,
        item_price REAL,
        item_category TEXT,      
        item_unit TEXT,
        item_tax_group TEXT,
        item_tax_pct REAL,
        UNIQUE(item_id)
      );
      CREATE INDEX idx_item ON items(item_id);
    ''');

    await db.execute('''
      CREATE TABLE supp_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        supp_parent_id TEXT,
        supp_id TEXT,
        supp_name TEXT,        
        supp_qty NUMBER,
        supp_price REAL,
        supp_category TEXT,  
        supp_uom TEXT,
        supp_tax_group TEXT,
        supp_tax_pct REAL
      );
      CREATE INDEX idx_supp_items ON supp_items(supp_id);
    ''');

    await db.execute('''
      CREATE TABLE sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,        
        sales_num TEXT,
        sales_timeStamp TEXT,
        sales_date TEXT,
        sales_time TEXT,
        sales_employee TEXT,         
        sales_store_id TEXT,
        sales_register_id TEXT,               
        sales_subtotal REAL,
        sales_discount REAL,
        sales_disc_pct REAL,
        sales_change REAL DEFAULT 0,
        sales_tax REAL,
        sales_total REAL,  
        sales_customer TEXT,  
        sales_status TEXT,
        sales_sync_frappe TEXT,
        loy_cust_card_num TEXT,
        loy_points_used REAL,
        loy_points_earned REAL,
        balance_points REAL,
        UNIQUE(sales_num)
      );
      CREATE INDEX idx_sale ON sales(sales_num);
    ''');

    await db.execute('''
      CREATE TABLE sales_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,        
        si_sale_num TEXT,
        si_id TEXT,        
        si_name TEXT,
        si_unit TEXT,
        si_code TEXT,
        si_barcode TEXT,
        si_category TEXT,
        si_qty NUMERIC,
        si_price REAL,
        si_tax_pct REAL,
        si_subtotal REAL,
        si_tax REAL,
        si_total REAL,
        si_discount REAL,
        si_disc_pct REAL        
      );
      CREATE INDEX idx_item_sale ON sales_items(si_sale_num);
    ''');

    await db.execute('''
      CREATE TABLE pay_mthds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,        
        pay_mthds_id TEXT,
        pay_mthds_name TEXT        
      );
      CREATE INDEX idx_pay_mthds ON pay_mthds(pay_mthds_id);
    ''');

    await db.execute('''
      CREATE TABLE payment_txn_mthds (
        id INTEGER PRIMARY KEY AUTOINCREMENT,        
        pay_txn_sale_num TEXT,
        pay_txn_id TEXT,
        pay_txn_name TEXT,
        pay_txn_amount REAL
      );
      CREATE INDEX idx_pay_txn ON payment_txn_mthds(pay_txn_id);
    ''');

    await db.execute('''
      CREATE TABLE zreport (
        id INTEGER PRIMARY KEY AUTOINCREMENT,        
        zr_num NUMERIC,
        zr_date TEXT,
        zr_employee TEXT,        
        zr_subtotal REAL,
        zr_tax REAL,
        zr_total REAL,
        zr_pay_method TEXT,
        zr_status TEXT
      );
      CREATE INDEX idx_zreport ON zreport(zr_num);
    ''');

    await db.execute('''
      CREATE TABLE xreport (
        id INTEGER PRIMARY KEY AUTOINCREMENT,        
        xr_num NUMERIC,
        xr_date TEXT,
        xr_employee TEXT,        
        xr_subtotal REAL,
        xr_tax REAL,
        xr_total REAL,
        xr_pay_method TEXT,
        xr_status TEXT
      );
      CREATE INDEX idx_xreport ON xreport(xr_num);
    ''');

    // await db.execute('''
    //   CREATE TABLE cash_flow (
    //     id INTEGER PRIMARY KEY AUTOINCREMENT,
    //     cf_num TEXT,
    //     cf_added REAL,
    //     cf_collected REAL,
    //     cf_removed REAL
    //   );
    //   CREATE INDEX idx_cashFlow ON cash_flow(cf_num);
    // ''');

    await db.execute('''
      CREATE TABLE shifts (
        id INTEGER PRIMARY KEY AUTOINCREMENT,        
        shift_num NUMERIC,
        shift_personnel_id TEXT,
        shift_in TEXT,
        shift_out TEXT        
      );
      CREATE INDEX idx_shifts ON shifts(shift_num);
    ''');

    await db.execute('''
      CREATE TABLE transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        txn_number TEXT,    
        txn_date TEXT,
        txn_time TEXT,
        txn_local_status,
        txn_posting_status TEXT,
        txn_receipt_num TEXT,
        txn_type TEXT,
        txn_store_num TEXT,
        txn_register_num TEXT,
        txn_customer TEXT,
        txn_cashier TEXT,
        txn_amount REAL
      );
      CREATE INDEX idx_txn ON transactions(txn_number);
    ''');
  }

  // this method update the db (fields, tables, etc)
  // set the number according to the new version of your db
  // KEEP ON MIND THE VERSION NUM SHOULD BE THE SAME IN '_onUpgrade' MAP

  Future<void> _onUpgrade(
      sqflite.Database db, int oldVersion, int newVersion) async {
    if (oldVersion == 0) {
      // The database is new, no migrations are needed
      return;
    }

    //release 1.46
    Map<int, List<String>> migrations = {
      3: [
        "DROP TABLE IF EXISTS clients;",
        """
        CREATE TABLE loy_custx (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          loy_custx_id TEXT,
          loy_custx_card_num TEXT,
          loy_custx_type TEXT,
          loy_custx_first_name TEXT,
          loy_custx_last_name TEXT,
          loy_custx_name TEXT,
          loy_custx_email TEXT,
          loy_custx_address TEXT,
          loy_custx_city TEXT,
          loy_custx_mobile TEXT,
          loy_custx_balance REAL,
          loy_custx_points INTEGER,
          loy_custx_scheme TEXT,
          loy_custx_group TEXT,
          loy_custx_frozen INTEGER,
          loy_custx_sync_frappe TEXT,
          UNIQUE(loy_custx_id)
        );
        """,
        """
        CREATE INDEX idx_loy_custx_id ON loy_custx(loy_custx_id);
        """,
        """
        CREATE TABLE loy_custx_txn (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          loy_custx_txn_user_id TEXT,
          loy_custx_txn_sale_num TEXT,
          loy_custx_txn_pts_used INTEGER,
          loy_custx_txn_ptx_earned INTEGER,
          loy_custx_txn_amt_disc REAL,
          loy_custx_txn_sync_frappe TEXT,
          UNIQUE(loy_custx_txn_user_id)
        );
        """,
        """
        CREATE INDEX idx_loy_custx_txn ON loy_custx_txn(loy_custx_txn_user_id);
        """
      ],
      //release 1.47
      4: [
        """
       CREATE TABLE stores_py_ava (
        id INTEGER PRIMARY KEY AUTOINCREMENT,      
        stores_py_id TEXT,                
        stores_py_ava_mthd_id TEXT     
      );
       """
      ],
      // release 1.53
      6: [
        """
       ALTER TABLE sales ADD COLUMN sales_change REAL DEFAULT 0;
       """
      ],
      // release 1.54
      7: [
        """
       ALTER TABLE stores ADD COLUMN stores_loyalty_enabled INTEGER DEFAULT 1;
       """,
        """
       ALTER TABLE stores ADD COLUMN stores_loyalty_allow_earn INTEGER DEFAULT 1;
       """,
        """
       ALTER TABLE stores ADD COLUMN stores_loyalty_allow_redeem INTEGER DEFAULT 1;
       """,
        """
       ALTER TABLE stores ADD COLUMN stores_loyalty_show_customer_ui INTEGER DEFAULT 1;
       """,
        """
       ALTER TABLE stores ADD COLUMN stores_loyalty_show_points_ui INTEGER DEFAULT 1;
       """,
        """
       ALTER TABLE stores ADD COLUMN stores_loyalty_show_receipt_details INTEGER DEFAULT 1;
       """
      ]
      // Add additional migrations here for other versions
    };

    for (int version = oldVersion + 1; version <= newVersion; version++) {
      List<String>? queries = migrations[version];
      if (queries != null) {
        for (String query in queries) {
          await db.execute(query);
        }
      }
    }
  }
//####################################
// CREATE
// ###################################

  Future<int> saveSale(Map<String, dynamic> data) async {
    var dbClient = await database;
    return await dbClient.transaction((txn) async {
      return await txn.insert('sales', data);
    });
  }

  Future<int> saveItemsSale(Map<String, dynamic> data) async {
    var dbClient = await database;
    return await dbClient.transaction((txn) async {
      logger.d('🧾 save item sale → $data');
      return await txn.insert('sales_items', data);
    });
  }

////////
  Future<int> saveSuppItemsSale(Map<String, dynamic> data) async {
    var dbClient = await database;
    return await dbClient.transaction((txn) async {
      return await txn.insert('supp_items', data);
    });
  }

  Future<int> saveShiftTime(Map<String, dynamic> data) async {
    var dbClient = await database;
    return await dbClient.transaction((txn) async {
      return await txn.insert('shifts', data);
    });
  }

  Future<int> saveTransaction(Map<String, dynamic> data) async {
    var dbClient = await database;
    return await dbClient.transaction((txn) async {
      return await txn.insert('transactions', data);
    });
  }

  Future<int> savePaymentMthd(Map<String, dynamic> data) async {
    var dbClient = await database;
    return await dbClient.transaction((txn) async {
      return await txn.insert('payment_txn_mthds', data);
    });
  }

  Future<int> saveNewCust(Map<String, dynamic> data) async {
    var dbClient = await database;
    return await dbClient.transaction((txn) async {
      return await txn.insert('loy_custx', data);
    });
  }

  Future<int> saleRestoreIndex(index) async {
    var dbClient = await database;
    //dummy data
    Map<String, dynamic> dummyData = {
      'id': index,
      'sales_num': '--------------',
      'sales_status': 'restoring system',
      'sales_sync_frappe': 'restore',
    };
    // Insert the dummy data into the database
    return await dbClient.transaction((txn) async {
      return await txn.insert('sales', dummyData);
    });
  }

//##################################
// READ
//##################################
  //validate user
  Future<Map<String, dynamic>?> validateUser(String personneId) async {
    Database dbClient = await database;
    List<Map<String, dynamic>> result = await dbClient.query(
      'users',
      columns: [
        'user_email',
        'user_first_name',
        'user_last_name',
        'user_personnel_id',
        'user_group',
        'user_img'
      ],
      where: 'user_personnel_id = ?',
      whereArgs: [personneId],
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  /// Fetches a single loyalty customer by their card number.
  Future<Map<String, dynamic>?> getCustByCardNumber(String cardNumber) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'loy_custx',
      where: 'loy_custx_card_num = ?',
      whereArgs: [cardNumber],
    );

    if (maps.isNotEmpty) {
      return maps.first;
    }
    return null;
  }

//Method to get customer by mobile number
  Future<Map<String, dynamic>?> getCustxMobile(String mobile) async {
    Database dbClient = await database;
    List<Map<String, dynamic>> result = await dbClient.query(
      'loy_custx',
      where: 'loy_custx_mobile = ?',
      whereArgs: [mobile],
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

//get the customer
  Future<Map<String, dynamic>?> getCustxId(String cusxId) async {
    Database dbClient = await database;
    List<Map<String, dynamic>> result = await dbClient.query(
      'loy_custx',
      columns: [
        'loy_custx_card_num',
        'loy_custx_points',
        'loy_custx_name',
      ],
      where: 'loy_custx_card_num = ?',
      whereArgs: [cusxId],
    );
    if (result.isNotEmpty) {
      return result.first;
    }
    return null;
  }

  //get info store name
  Future<Map<String, String?>?> getInfoStore(String storeId) async {
    var dbClient = await database;
    var result = await dbClient.rawQuery(
      """
        SELECT 
          stores_name,
          stores_address,
          stores_country,
          stores_phone_num,
          stores_registration_num,
          stores_bcrs_code,
          stores_opening_hours 
        FROM 
          stores 
        WHERE 
          stores_id = ? ORDER BY stores_id LIMIT 1;
      """,
      [storeId],
    );
    if (result.isNotEmpty) {
      return {
        'stores_name': result.first['stores_name'] as String?,
        'stores_address': result.first['stores_address'] as String?,
        'stores_country': result.first['stores_country'] as String?,
        'stores_phone_num': result.first['stores_phone_num'] as String?,
        'stores_registration_num':
            result.first['stores_registration_num'] as String?,
        'stores_bcrs_code': result.first['stores_bcrs_code'] as String?,
        'stores_opening_hours': result.first['stores_opening_hours'] as String?,
      };
    }

    return null;
  }

  //get available payment methods
  Future<List<String>> getAvailablePaymentMethods(String storeId) async {
    try {
      var dbClient = await database;
      var result = await dbClient.rawQuery(
        """
        SELECT stores_py_ava_mthd_id 
        FROM stores_py_ava 
        WHERE stores_py_id = ?;
      """,
        [storeId],
      );

      if (result.isNotEmpty) {
        return result
            .map((row) => row['stores_py_ava_mthd_id'].toString())
            .toList();
      }
      return [];
    } catch (e) {
      // Manejo de errores
      logger.d("Error fetching payment methods for store $storeId: $e");
      return [];
    }
  }

  //get pay mthd name
  Future<String?> getPayMthdName(String payMthdId) async {
    var dbClient = await database;
    var result = await dbClient.rawQuery(
      "SELECT pay_mthds_name FROM pay_mthds WHERE pay_mthds_id = ? ORDER BY pay_mthds_id LIMIT 1;",
      [payMthdId],
    );

    if (result.isNotEmpty) {
      return result.first['pay_mthds_name'] as String?;
    }

    return null;
  }

  //get last transaction num
  Future<int?> getLastTxnNum() async {
    var dbClient = await database;
    var result = await dbClient
        .rawQuery("SELECT id FROM transactions ORDER BY id DESC LIMIT 1");
    if (result.isNotEmpty) {
      return int.tryParse(result.first['id'].toString());
    }
    return null;
  }

  //get last transaction num shift
  Future<Map<String, String?>?> checkSessionOpen(String userId) async {
    var dbClient = await database;
    var result = await dbClient.rawQuery(
      "SELECT shift_in, shift_out FROM shifts WHERE shift_personnel_id = ? AND shift_out = ''  ORDER BY id DESC LIMIT 1  ",
      [userId],
    );

    if (result.isNotEmpty) {
      return {
        'shift_in': result.first['shift_in'] as String?,
        'shift_out': result.first['shift_out'] as String?,
      };
    }

    return null;
  }

  //get supp item
  Future<Map<String, dynamic>?> getSuppItem(String parentId) async {
    var dbClient = await database;
    var result = await dbClient.rawQuery(
      "SELECT supp_id,supp_name,supp_price,supp_uom,supp_tax_pct FROM supp_items WHERE supp_parent_id = ?  ORDER BY id DESC LIMIT 1 ",
      [parentId],
    );

    if (result.isNotEmpty) {
      return {
        'supp_id': result.first['supp_id'] as String?,
        'supp_name': result.first['supp_name'] as String?,
        'supp_price': result.first['supp_price'] as double?,
        'supp_uom': result.first['supp_uom'] as String?,
        'supp_tax_pct': result.first['supp_tax_pct'] as double?,
      };
    }

    return null;
  }

  //get stores
  Future<List<String>> getStores() async {
    var dbClient = await database;
    var result = await dbClient.rawQuery("SELECT stores_id FROM stores");

    if (result.isNotEmpty) {
      return result.map((row) => row['stores_id'].toString()).toList();
    }

    return [];
  }

  //get stores location info
  Future<Map<String, String?>?> getStoreInfo(storeId) async {
    var dbClient = await database;
    var result = await dbClient.rawQuery(
      "SELECT stores_invent_location, stores_legal_entity FROM stores WHERE stores_id = ? LIMIT 1",
      [storeId],
    );

    if (result.isNotEmpty) {
      var location = result.first['stores_invent_location']?.toString();
      var legalEntity = result.first['stores_legal_entity']?.toString();

      return {
        'location': location,
        'legalEntity': legalEntity,
      };
    }

    return null;
  }

  Future<Map<String, dynamic>?> getStoreLoyaltyPolicy(String storeId) async {
    final dbClient = await database;
    final result = await dbClient.rawQuery(
      '''
      SELECT
        stores_loyalty_enabled,
        stores_loyalty_allow_earn,
        stores_loyalty_allow_redeem,
        stores_loyalty_show_customer_ui,
        stores_loyalty_show_points_ui,
        stores_loyalty_show_receipt_details
      FROM stores
      WHERE stores_id = ?
      LIMIT 1
      ''',
      [storeId],
    );

    if (result.isEmpty) {
      return null;
    }
    return result.first;
  }

  //get registers
  Future<List<String>> getRegisters(String storeId) async {
    var dbClient = await database;

    var result = await dbClient.rawQuery(
        "SELECT registers_id FROM registers WHERE registers_store_id = ?",
        [storeId]);

    if (result.isNotEmpty) {
      return result.map((row) => row['registers_id'].toString()).toList();
    }

    return [];
  }

  //get summary total sales
  Future<double> getTotalSales(String userID, String dateIn) async {
    var dbClient = await database;
    var result = await dbClient.rawQuery("""
    SELECT SUM(payment_txn_mthds.pay_txn_amount) AS total_sales
    FROM sales
    JOIN payment_txn_mthds ON payment_txn_mthds.pay_txn_sale_num = sales.sales_num
    WHERE sales.sales_employee = ?    
    AND sales.sales_timeStamp BETWEEN ? AND datetime('now', 'localtime')
    AND sales.sales_status = 'Complete';
    """, [userID, dateIn]);

    if (result.isNotEmpty) {
      var totalSales = result.first['total_sales'];

      if (totalSales != null) {
        if (totalSales is int) {
          return totalSales.toDouble();
        } else if (totalSales is double) {
          return totalSales;
        } else if (totalSales is num) {
          return totalSales.toDouble();
        }
      }
    }

    return 0.0;
  }

  //get summary totals
  Future<double> getTotals(String field, String userID, String dateIn) async {
    var dbClient = await database;
    var result = await dbClient.rawQuery("""
    SELECT SUM($field) AS $field
    FROM sales 
    WHERE sales_employee = ?       
    AND sales_timeStamp BETWEEN ? AND datetime('now', 'localtime')
    AND $field > 0
    AND sales.sales_status = 'Complete'
    """, [userID, dateIn]);

    if (result.isNotEmpty) {
      var totalSales = result.first[field];

      if (totalSales != null) {
        // check the value is a double
        return (totalSales is int)
            ? totalSales.toDouble()
            : totalSales as double;
      }
    }

    return 0.0;
  }

  //get summary totals
  Future<double> getTotalReturns(
      String field, String userID, String dateIn) async {
    var dbClient = await database;
    var result = await dbClient.rawQuery("""
    SELECT SUM($field) AS $field
    FROM sales 
    WHERE sales_employee = ?    
    AND sales_timeStamp BETWEEN ? AND datetime('now', 'localtime')
    AND $field < 0
    """, [userID, dateIn]);

    if (result.isNotEmpty) {
      var totalSales = result.first[field];

      if (totalSales != null) {
        // check the value is a double
        return (totalSales is int)
            ? totalSales.toDouble()
            : totalSales as double;
      }
    }

    return 0.0;
  }

  //returns combined receipt
  Future<double> getTotalReturnsCombinedReceipt(
      String field, String userID, String dateIn) async {
    final allowedFields = [
      'si_total',
    ];
    if (!allowedFields.contains(field)) {
      throw ArgumentError('Campo no permitido para la sumatoria.');
    }

    var dbClient = await database;
    var result = await dbClient.rawQuery("""
    SELECT 
      ROUND(SUM(si.$field), 2) AS total_negative
    FROM 
      sales AS s
    INNER JOIN 
      sales_items AS si ON si.si_sale_num = s.sales_num
    WHERE 
      s.sales_employee = ?        
      AND s.sales_timeStamp BETWEEN ? AND datetime('now', 'localtime')
      AND si.si_total < 0;        
  """, [userID, dateIn]);

    if (result.isNotEmpty) {
      var totalSales = result.first['total_negative'];

      if (totalSales != null) {
        // Convierte el resultado a double de manera segura
        return double.tryParse(totalSales.toString()) ?? 0.0;
      }
    }
    return 0.0;
  }

// get count registers per user
  Future<int> getCountTnx(String field, String userID, String dateIn) async {
    var dbClient = await database;
    var result = await dbClient.rawQuery("""
    SELECT COUNT($field) AS total_count
    FROM sales 
    WHERE sales_employee = ?       
    AND sales_timeStamp BETWEEN ? AND datetime('now', 'localtime')
    AND sales.sales_status = 'Complete'
    """, [userID, dateIn]);

    if (result.isNotEmpty) {
      var totalCount = result.first['total_count'];

      if (totalCount != null) {
        return (totalCount as num).toInt();
      }
    }

    return 0;
  }

  // get count registers per user and method of payment
  Future<int> getCountTnxMethod(
      String userID, String dateIn, String payMethod) async {
    var dbClient = await database;
    var result = await dbClient.rawQuery("""
    SELECT COUNT(payMthd.pay_txn_name) AS total_txn_method
    FROM sales
    JOIN payment_txn_mthds AS payMthd
    ON sales.sales_num = payMthd.pay_txn_sale_num
    AND sales.sales_employee = ?
    AND sales_timeStamp BETWEEN ? AND datetime('now', 'localtime')
    WHERE payMthd.pay_txn_name = ?;
    """, [userID, dateIn, payMethod]);

    if (result.isNotEmpty) {
      var totalCount = result.first['total_txn_method'];

      if (totalCount != null) {
        return (totalCount is double) ? totalCount.toInt() : totalCount as int;
      }
    }

    return 0;
  }

  //get summary total sales
  Future<double> getTotalAmount(
      String userID, String payMethod, String dateIn) async {
    var dbClient = await database;
    var result = await dbClient.rawQuery("""
    SELECT COALESCE(SUM(p.pay_txn_amount), 0) AS total_cash
    FROM sales AS s
    JOIN payment_txn_mthds AS p ON p.pay_txn_sale_num = s.sales_num
    WHERE s.sales_employee = ?
      AND p.pay_txn_name = ?
      AND s.sales_timeStamp BETWEEN ? AND datetime('now', 'localtime')
      AND s.sales_status = 'Complete';
    """, [userID, payMethod, dateIn]);

    if (result.isNotEmpty) {
      var totalSales = result.first['total_cash'];

      if (totalSales != null) {
        return totalSales is num
            ? totalSales.toDouble()
            : double.parse(totalSales.toString());
      }
    }

    return 0.0;
  }

  //get all items
  Future<List<Map<String, dynamic>>> queryAllItems() async {
    Database dbClient = await database;
    return await dbClient.query('items');
  }

  Future<List<Map<String, dynamic>>> queryItemsByStore(String storeId) async {
    final dbClient = await database;
    final normalized = storeId.trim();
    if (normalized.isEmpty) {
      return dbClient.query('items');
    }

    return dbClient.query(
      'items',
      where: 'item_store = ?',
      whereArgs: [normalized],
    );
  }

  //get all sales
  Future<List<Map<String, dynamic>>> queryAllSales() async {
    Database dbClient = await database;
    return await dbClient.query('sales');
  }

  //get all items saled
  Future<List<Map<String, dynamic>>> queryAllItemsSale() async {
    Database dbClient = await database;
    return await dbClient.query('items_sale');
  }

  //get - Send data to frappe
  //######################################################################
  Future<List<Map<String, dynamic>>> getAllSalesWithItemsToSync() async {
    var dbClient = await database;

    // check all sales
    var salesResults = await dbClient.rawQuery(
        """SELECT * FROM sales WHERE (sales_sync_frappe IS NULL OR sales_sync_frappe = '') AND sales_status = 'Complete'""");

    // create a map to add the items
    List<Map<String, dynamic>> salesWithItemsList = [];

    for (var sale in salesResults) {
      // check the items per sale
      var itemsResults = await dbClient.rawQuery(
        'SELECT * FROM sales_items WHERE si_sale_num = ?',
        [sale['sales_num']],
      );

      var paymthds = await dbClient.rawQuery(
        'SELECT * FROM payment_txn_mthds WHERE pay_txn_sale_num = ?',
        [sale['sales_num']],
      );

      LinkedHashMap<String, dynamic> saleJson =
          LinkedHashMap<String, dynamic>();

      saleJson['sale_id'] = sale['id'];
      saleJson['sales_num'] = sale['sales_num'];
      saleJson['sales_timeStamp'] = sale['sales_timeStamp'];
      saleJson['sales_date'] = sale['sales_date'];
      saleJson['sales_time'] = sale['sales_time'];
      if (sale['loy_cust_card_num'] != null &&
          sale['loy_cust_card_num'].toString().isNotEmpty) {
        saleJson['loy_cust_card_num'] = sale['loy_cust_card_num'];
      }
      saleJson['items'] = itemsResults.map((item) {
        return {
          'id': item['id'],
          'si_sale_num': item['si_sale_num'],
          'si_id': item['si_id'],
          'si_name': item['si_name'],
          'si_unit': item['si_unit'],
          'si_code': item['si_code'],
          'si_barcode': item['si_barcode'],
          'si_category': item['si_category'],
          'si_qty': item['si_qty'],
          'si_price': item['si_price'],
          'si_tax_pct': item['si_tax_pct'],
          'si_subtotal': item['si_subtotal'],
          'si_tax': item['si_tax'],
          'si_total': item['si_total'],
          'si_discount_amount': item['si_discount'] ?? 0.0,
          'si_discount_percent': item['si_disc_pct'] ?? 0.0,
        };
      }).toList();

      saleJson['sales_subtotal'] = sale['sales_subtotal'];
      saleJson['sales_tax'] = sale['sales_tax'];
      saleJson['sales_total'] = sale['sales_total'];
      saleJson['sales_discount_amount'] = sale['sales_discount'] ?? 0.0;
      saleJson['sales_discount_percent'] = sale['sales_disc_pct'] ?? 0.0;
      saleJson['sales_change'] = sale['sales_change'] ?? 0.0;

      // saleJson['sales_pay_method'] = sale['sales_pay_method'];

      saleJson['sale_pay_methods'] = paymthds.map((paym) {
        return {
          'tender_type_id': paym['pay_txn_id'],
          'payment_name': paym['pay_txn_name'],
          'amount_tendered': paym['pay_txn_amount'],
        };
      }).toList();

      saleJson['sales_cashier'] = sale['sales_employee'];
      saleJson['sales_store'] = sale['sales_store_id'];
      saleJson['sales_registerId'] = sale['sales_register_id'];

      // add sale - items in the main list
      salesWithItemsList.add(saleJson);
    }

    return salesWithItemsList;
  }

  double _asDouble(dynamic value, {double fallback = 0.0}) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  double _round2(double value) => double.parse(value.toStringAsFixed(2));

  Map<String, dynamic> _mapSalesItemToOrderItem(Map<String, dynamic> item) {
    final qty = _asInt(item['si_qty'], fallback: 1);
    final taxPct = _asDouble(item['si_tax_pct']);
    final unitNetBeforeDiscount = _asDouble(item['si_price']);
    final unitGrossBeforeDiscount = taxPct <= 0
        ? _round2(unitNetBeforeDiscount)
        : _round2(unitNetBeforeDiscount * (1 + (taxPct / 100)));

    return {
      'item_img': '',
      'item_name': item['si_name'] ?? '',
      'item_qty': qty,
      'item_price': unitGrossBeforeDiscount,
      'item_unit': item['si_unit'] ?? '',
      'item_id': item['si_id'] ?? '',
      'item_barcode': item['si_barcode'] ?? '',
      'item_category': item['si_category'] ?? '',
      'item_tax_group': '${taxPct.toStringAsFixed(0)}%',
      'item_tax_pct': taxPct,
      'item_total': _round2(_asDouble(item['si_total'])),
      'item_subtotal': _round2(_asDouble(item['si_subtotal'])),
      'item_tax': _round2(_asDouble(item['si_tax'])),
      'item_disc_amount': _round2(_asDouble(item['si_discount'])),
      'item_disc_perct': _round2(_asDouble(item['si_disc_pct'])),
      'item_supplementary': const <Map<String, dynamic>>[],
    };
  }

  Future<List<Map<String, dynamic>>> getAllPendingTxn() async {
    var dbClient = await database;

    // See all pending sales
    var salesResults = await dbClient.rawQuery(
        "SELECT * FROM sales WHERE sales_status = 'Pending' ORDER BY id DESC");

    List<Map<String, dynamic>> salesPending = [];

    for (var sale in salesResults) {
      // See the articles for each sale
      var itemsResults = await dbClient.rawQuery(
        'SELECT * FROM sales_items WHERE si_sale_num = ?',
        [sale['sales_num']],
      );

      // Create a map for the current sale
      Map<String, dynamic> saleJson = {};

      saleJson['sale_date'] = sale['sales_date'];
      saleJson['sale_num'] = sale['sales_num'];
      saleJson['sale_total'] = _asDouble(sale['sales_total']);

      // Assign the sale items to the 'items' key
      saleJson['items'] = itemsResults.map((item) {
        return _mapSalesItemToOrderItem(item);
      }).toList();

      //Add the map of the sale to the list
      salesPending.add(saleJson);
    }

    return salesPending;
  }

  //get all item to history
  // ######################################################################
  Future<List<Map<String, dynamic>>> getAllSalesHistory(
      {int recentDays = 7}) async {
    var dbClient = await database;

    final safeRecentDays = recentDays <= 0 ? 7 : recentDays;

    // Keep local history lightweight: load only recent sales by default,
    // but always include unsynced complete sales regardless of age.
    var salesResults = await dbClient.rawQuery(
      """
      SELECT *
      FROM sales
      WHERE sales_date >= date('now', '-$safeRecentDays day')
         OR (sales_status = 'Complete' AND TRIM(COALESCE(sales_sync_frappe, '')) = '')
      ORDER BY sales_date DESC, sales_time DESC, id DESC
      """,
    );

    // create a map to add the items
    List<Map<String, dynamic>> salesWithItemsList = [];

    for (var sale in salesResults) {
      // check the items per sale
      var itemsResults = await dbClient.rawQuery(
        'SELECT * FROM sales_items WHERE si_sale_num = ?',
        [sale['sales_num']],
      );

      var paymthds = await dbClient.rawQuery(
        'SELECT * FROM payment_txn_mthds WHERE pay_txn_sale_num = ?',
        [sale['sales_num']],
      );

      LinkedHashMap<String, dynamic> saleJson =
          LinkedHashMap<String, dynamic>();

      // saleJson['sale_id'] = sale['id'];
      saleJson['sales_num'] = sale['sales_num'];
      // saleJson['sales_timeStamp'] = sale['sales_timeStamp'];
      saleJson['sales_date'] = sale['sales_date'];
      saleJson['sales_time'] = sale['sales_time'];
      saleJson['loy_cust_card_num'] = sale['loy_cust_card_num'];
      saleJson['loy_points_used'] = sale['loy_points_used'];
      saleJson['loy_points_earned'] = sale['loy_points_earned'];
      saleJson['balance_points'] = sale['balance_points'];
      saleJson['sales_change'] = _asDouble(sale['sales_change']);

      saleJson['items'] = itemsResults.map((item) {
        final mapped = _mapSalesItemToOrderItem(item);
        return {
          ...mapped,
          'id': item['id'],
          'item_sale_num': item['si_sale_num'],
          'item_code': item['si_code'],
        };
      }).toList();

      saleJson['sales_subtotal'] = sale['sales_subtotal'];
      saleJson['sales_tax'] = sale['sales_tax'];
      saleJson['sales_total'] = sale['sales_total'];
      saleJson['sales_status'] = sale['sales_status'];
      saleJson['sales_discount'] = sale['sales_discount'] ?? 0;

      // saleJson['sales_pay_method'] = sale['sales_pay_method'];

      saleJson['sale_pay_methods'] = paymthds.map((paym) {
        return {
          'payment_txn_num': paym['pay_txn_sale_num'],
          'tender_type_id': paym['pay_txn_id'],
          'payment_name': paym['pay_txn_name'],
          'amount_tendered': paym['pay_txn_amount'],
        };
      }).toList();

      saleJson['sales_cashier'] = sale['sales_employee'];
      saleJson['sales_store'] = sale['sales_store_id'];
      saleJson['sales_registerId'] = sale['sales_register_id'];

      // add sale - items in the main list
      salesWithItemsList.add(saleJson);
    }

    return salesWithItemsList;
  }

  /// Keep only synced sales older than [retentionDays] pruned from local DB.
  /// Unsynced sales are always preserved, regardless of age.
  Future<Map<String, int>> purgeSyncedSalesOlderThan(
      {int retentionDays = 7}) async {
    final dbClient = await database;
    final safeRetentionDays = retentionDays <= 0 ? 7 : retentionDays;
    final cutoffDate = DateFormat('yyyy-MM-dd')
        .format(DateTime.now().subtract(Duration(days: safeRetentionDays)));

    final candidates = await dbClient.rawQuery(
      '''
      SELECT sales_num
      FROM sales
      WHERE sales_date < ?
        AND sales_status = 'Complete'
        AND TRIM(COALESCE(sales_sync_frappe, '')) != ''
      ''',
      [cutoffDate],
    );

    if (candidates.isEmpty) {
      return {
        'deleted_sales': 0,
        'deleted_items': 0,
        'deleted_payments': 0,
      };
    }

    int deletedSales = 0;
    int deletedItems = 0;
    int deletedPayments = 0;

    await dbClient.transaction((txn) async {
      for (final row in candidates) {
        final saleNum = row['sales_num']?.toString() ?? '';
        if (saleNum.isEmpty) continue;

        deletedItems += await txn.delete(
          'sales_items',
          where: 'si_sale_num = ?',
          whereArgs: [saleNum],
        );
        deletedPayments += await txn.delete(
          'payment_txn_mthds',
          where: 'pay_txn_sale_num = ?',
          whereArgs: [saleNum],
        );
        deletedSales += await txn.delete(
          'sales',
          where: 'sales_num = ?',
          whereArgs: [saleNum],
        );
      }
    });

    logger.i(
      'Retention cleanup completed (cutoff=$cutoffDate): '
      'sales=$deletedSales, items=$deletedItems, payments=$deletedPayments',
    );

    return {
      'deleted_sales': deletedSales,
      'deleted_items': deletedItems,
      'deleted_payments': deletedPayments,
    };
  }

//####################################
// UPDATE
//####################################

  //update sale
  Future<int> updateSale(Map<String, dynamic> row) async {
    Database dbClient = await database;
    int id = row['id'];
    return await dbClient
        .update('sales', row, where: 'id = ?', whereArgs: [id]);
  }

  //update shift out
  Future<int> updateShiftOut(String userId, DateTime shiftOutTime) async {
    Database dbClient = await database;
    String formattedDate =
        DateFormat('yyyy-MM-dd HH:mm:ss').format(shiftOutTime);

    List<Map<String, dynamic>> result = await dbClient.rawQuery('''
    SELECT id FROM shifts 
    WHERE shift_personnel_id = ? AND (shift_out IS NULL OR shift_out = '') 
    ORDER BY id DESC 
    LIMIT 1
    ''', [userId]);

    if (result.isNotEmpty) {
      int lastId = result.first['id'];

      // update the register
      return await dbClient.update(
        'shifts',
        {'shift_out': formattedDate},
        where: 'id = ?',
        whereArgs: [lastId],
      );
    }

    // return 0 if there is not result
    return 0;
  }

  //update sale
  Future<int> frappeSyncConfirmation(
      String salesNum, String syncStatus, String loyaltyCardNum) async {
    Database dbClient = await database;

    // Create a map with the field to update
    Map<String, dynamic> updateValues = {
      'sales_sync_frappe': syncStatus,
    };

    // Perform the update operation
    int result = await dbClient.update(
      'sales',
      updateValues,
      where: 'sales_num = ?',
      whereArgs: [salesNum],
    );

    return result;
  }

//####################################
// DELETE
//####################################

  //delete sale
  Future<int> deleteSale(int id) async {
    Database dbClient = await database;
    return await dbClient.delete('sales', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteStoreTxn(String saleNum) async {
    Database dbClient = await database;

    // Use a transaction to ensure both deletions occur together
    await dbClient.transaction((txn) async {
      try {
        await txn.delete('sales', where: 'sales_num = ?', whereArgs: [saleNum]);
        await txn.delete('sales_items',
            where: 'si_sale_num = ?', whereArgs: [saleNum]);

        logger.d(
            "Transaction with sale_num $saleNum removed from both tables correctly.");
      } catch (e) {
        logger.d("Error deleting transaction with sale_num $saleNum: $e");
      }
    });
  }
}
