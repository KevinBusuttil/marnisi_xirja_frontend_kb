// ignore: dangling_library_doc_comments
/// Class manage api routes to send and get data from frappe
///
/// Arguments:
/// * [basePathGet] base path to get data from the server.
/// * [basePathPost]  base path to post data from the server.
/// * [getProductsPaola]  method to fetch paola products.
/// * [getProducts]  method to fetch others stores products.
/// * [getUsers]  method to fetch users to login xirja.
/// * [getStores]  method to fetch stores.
/// * [getRegisters] method to fetch cashier machine codes per store.
/// * [getPayMthds]  method to fetch payment methods.
/// * [getLoyUsers]  method to fetch loyalty customers.
/// * [getLastReceiptNumStore] method to fetch receipt number - !obsolete.
/// * [postProducts] method to post all sales
/// * [postCustomers] method to post all loyalty customer txn

class ApiRoutes {
  //base path
  static const String basePathGet = "/api/method/xirja_marnisi.api.bridge";
  static const String basePathPost = "/api/method/xirja_marnisi.api.bridge";

  //End Points
  //paola endpoint
  static const String getProductsPaola = "$basePathGet.get_all_products_paola";

  // get data
  static const String getProducts = "$basePathGet.get_all_products";
  static const String getUsers = "$basePathGet.get_all_users";
  static const String getStores = "$basePathGet.get_all_stores";
  static const String getRegisters = "$basePathGet.get_all_registers";
  static const String getPayMthds = "$basePathGet.get_pay_mthds";
  static const String getLoyUsers = "$basePathGet.xirja_loy_users";
  static const String getLoyUsersByCardNum = "$basePathGet.get_retail_loy_user";
  static const String getSalesHistory = "$basePathGet.get_sales_history";

  //get data with arguments
  static const String getLastReceiptNumStore = "$basePathGet.get_receipt_index";

  // post data
  static const String postProducts = "$basePathPost.post_all_sales";
  static const String createLoyUser = "$basePathGet.create_retail_loy_user";
  // static const String postCustomers = "$basePathPost.post_customers";

  // Marnisi (Frappe v16 + xirja_marnisi)
  static const String marnisiBasePath = "/api/method/xirja_marnisi.api";
  static const String marnisiLogin = "/api/method/login";
  static const String marnisiLoginWithPersonalId =
      "$marnisiBasePath.auth.login_with_personal_id";

  static const String marnisiGetContext = "$marnisiBasePath.auth.get_context";
  static const String marnisiReceiptSettings =
      "$marnisiBasePath.settings.get_receipt_settings";
  static const String marnisiListAssignedVineyards =
      "$marnisiBasePath.vineyard.list_assigned";

  static const String marnisiItemList = "$marnisiBasePath.item.list";
  static const String marnisiItemCreate = "$marnisiBasePath.item.create";
  static const String marnisiItemUpdate = "$marnisiBasePath.item.update";
  static const String marnisiItemSetEnabled =
      "$marnisiBasePath.item.set_enabled";
  static const String marnisiItemAdjustStock =
      "$marnisiBasePath.item.adjust_stock";
  static const String marnisiItemMovements =
      "$marnisiBasePath.item.list_movements";

  static const String marnisiPackageList = "$marnisiBasePath.package.list";
  static const String marnisiPackageUpsert = "$marnisiBasePath.package.upsert";

  static const String marnisiBookingList = "$marnisiBasePath.booking.list";
  static const String marnisiBookingCreate = "$marnisiBasePath.booking.create";
  static const String marnisiBookingUpdateStatus =
      "$marnisiBasePath.booking.update_status";
  static const String marnisiBookingGet = "$marnisiBasePath.booking.get";
}
