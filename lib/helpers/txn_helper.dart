import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_admin/constants/shared_values.dart';
import 'package:web_admin/services/database_service.dart';

/// class TxnHelper storage the txn as a logs on the DB
/// enum(EVENT) to manage the vars for the diferents events, is possible add more if is it required
/// enum(LocalEvent) status of the event
/// enum(PostingStatus) status of the posting data to the server
///
/// * [SqlLiteService] object manage db
/// * [selectedStoreId] store id
/// * [selectedRegisterId] cashier machine id
/// * [userCode] cashier id
/// * [lastTxnNum] receipt num - obsolete

// Enum to set the default values for events
enum Event {
  logon,
  logOut,
  printInv,
  generateXReport,
  printXReport,
  generateZReport,
  printZReport,
  sales,
  setCashQty,
  drawCash,
  voided,
  refund,
  pendingTxn,
}

enum LocalEvent { successful, pending }

enum PostingStatus { posted, voided, pending, none }

class TxnHelper {
  static final _dbSqlLiteHelper = SqlLiteService();
  static String selectedStoreId = '';
  static String selectedRegisterId = '';
  static String userCode = '';
  static int lastTxnNum = 0;

  static double _roundToTwoDecimals(double number) {
    return double.parse(number.toStringAsFixed(2));
  }

  // Associate enum vars to string values
  static const Map<Event, String> eventStrings = {
    Event.logon: 'Logon',
    Event.logOut: 'Logoff',
    Event.printInv: 'Print Invoice',
    Event.generateXReport: 'Generate X report',
    Event.printXReport: 'Print X report',
    Event.generateZReport: 'Generate Z report',
    Event.printZReport: 'Print Z report',
    Event.sales: 'Sales',
    Event.setCashQty: 'Starting amount',
    Event.drawCash: 'Collected Cash',
    Event.voided: 'Voided',
    Event.refund: 'Refund',
    Event.pendingTxn: 'StoreTxn',
  };

  static const Map<LocalEvent, String> localEventStrings = {
    LocalEvent.successful: 'Successful',
    LocalEvent.pending: 'Pending',
  };

  static const Map<PostingStatus, String> postingStatusStrings = {
    PostingStatus.posted: 'Posted',
    PostingStatus.voided: 'Voided',
    PostingStatus.pending: 'Pending',
    PostingStatus.none: 'None',
  };

  static Future<void> _loadSavedSettings() async {
    final prefs = await SharedPreferences.getInstance();

    selectedStoreId = prefs.getString('selectedStore') ?? '';
    selectedRegisterId = prefs.getString('selectedRegister') ?? '';
    userCode = prefs.getString(StorageKeys.userId) ?? '';
  }

  static Future<void> saveTxn({
    LocalEvent txnLocalStatus = LocalEvent.pending,
    required Event txnType,
    required String txnReceiptNum,
    required double txnAmount,
    PostingStatus txnStatus = PostingStatus.pending,
  }) async {
    await _loadSavedSettings();
    final int lastTxnNum = await _dbSqlLiteHelper.getLastTxnNum() ?? 0;
    final String txnNumber = '$selectedStoreId-$selectedRegisterId-${(lastTxnNum + 1).toString().padLeft(5, '0')}';
    final String txnDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
    final String txnTime = DateFormat('HH:mm:ss').format(DateTime.now());
    final String localStatusTxn = localEventStrings[txnLocalStatus]!;
    final String txnTypeString = eventStrings[txnType]!;
    final String statusTxn = postingStatusStrings[txnStatus]!;
    final String txnStoreNum = selectedStoreId;
    final String txnRegisterNum = selectedRegisterId;
    //pending set txnCustomer to dynamic
    const String txnCustomer = 'MSR-000125';
    final String txnCashier = userCode;

    Map<String, dynamic> data = {
      'txn_number': txnNumber,
      'txn_date': txnDate,
      'txn_time': txnTime,
      'txn_local_status': localStatusTxn,
      'txn_receipt_num': txnReceiptNum,
      'txn_type': txnTypeString,
      'txn_store_num': txnStoreNum,
      'txn_register_num': txnRegisterNum,
      'txn_customer': txnCustomer,
      'txn_cashier': txnCashier,
      'txn_amount': _roundToTwoDecimals(txnAmount) * -1,
      'txn_posting_status': statusTxn,
    };
    await _dbSqlLiteHelper.saveTransaction(data);
  }
}
