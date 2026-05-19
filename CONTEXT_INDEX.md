# Xirja Frontend Context Index

## Core POS Flow
- `lib/views/screens/sales_register_pos_screen 2.dart`: main POS cart, payments, loyalty handling, receipt trigger, and discounted subtotal/tax values for printed receipt payload.
- `lib/helpers/sales_pricing_calculator.dart`: source of truth for subtotal/tax/discount/total calculations (includes return guard to prevent negative qty lines from being treated as discounts).
- `lib/helpers/payment_flow_helper.dart`: source of truth for payment-entry normalization, payout (negative amount due) handling, and balance/change calculations.
- `lib/helpers/payment_method_display_helper.dart`: resolves receipt-safe payment method labels from cached payment rows, preserving order and removing duplicates.
- `lib/helpers/sales_history_helper.dart`: reusable payment parsing helpers (cash tendered/change calculations) used by POS and history.
- `lib/helpers/item_search_filter_helper.dart`: sales-item search filtering (defaults to all items when search is empty).
- `lib/helpers/tour_register_helper.dart`: tour status and package-to-register quantity resolution for register-side tour loading.
- `lib/helpers/marnisi_pos_restrictions.dart`: temporary POS feature flags/restrictions (hidden payment buttons, hidden tour menu/action, single locked store/register selection).
- `lib/helpers/android_printer_discovery.dart`: Android Bluetooth paired-printer discovery + native receipt sending (`MethodChannel('xirja/printers')`) with MAC-address and printer-name extraction.
  - Includes `printSdkSampleReceipt(...)` helper to trigger a plain-text SDK sample print path from settings.
- `lib/helpers/printer_debug_log_helper.dart`: persistent Android printer debug logger (append/get-path/clear log file via `MethodChannel('xirja/printers')`).
- `lib/views/components/dialog_discount.dart`: item/order discount UI and per-line discount behavior.

## Store + Local Sync
- `lib/splash.dart`: startup sync for stores/registers/items/payment methods.
- `lib/services/database_service.dart`: SQLite schema, migrations, sync payload builders, local history retention.
- `lib/services/startup_sync_service.dart`: reusable startup-style master sync (users/items/stores/registers/payment methods) callable from settings without app restart.
- `lib/helpers/store_loyalty_policy.dart`: per-store loyalty policy mapping and effective behavior.

## Printing + History
- `lib/services/printer_invoice_service.dart`: thermal receipt composition + drawer open command (discount formatting and totals ordering for receipts).
- `lib/helpers/loyalty_receipt_helper.dart`: loyalty section visibility logic for receipts.
- `lib/helpers/app_build_info.dart`: app version/build display helper for on-screen diagnostics.
- `lib/helpers/portal_header_time_helper.dart`: top-bar elapsed/session clock formatting helpers (minute precision).
- `lib/helpers/pos_tablet_layout_helper.dart`: tablet-specific POS height breakpoints and flex sizing helpers used to prevent keypad/action panel overflow.
- `android/app/src/main/kotlin/com/example/xirja_frontend/MainActivity.kt`: Android bridge for paired Bluetooth printer listing + receipt printing (`printRawReceipt`) with SDK-first flow for Bixolon models, guarded `Throwable` capture around SDK invocation, build-identity logging, sample-compat bootstrap in `onCreate()`, Bixolon vendor log initialization, lazy SDK construction only when printer actions invoke the SDK, sample-style runtime permission requests (storage/location + scan/connect), and optional sample-compat `StrictMode` parity.
- `android/app/build.gradle`: BIXOLON investigation build flavors (`matrixa`, `matrixb`, `matrixc`, `sampleparity`) for lifecycle-vs-manifest-vs-targetSdk isolation plus a dedicated sample-parity release target.
- `android/app/src/matrixb/AndroidManifest.xml`, `android/app/src/matrixc/AndroidManifest.xml`: sample-parity manifest overlays (`largeHeap`, `BLUETOOTH_ADVERTISE`, location/storage declarations, `org.apache.http.legacy`) for matrix builds.
- `android/app/src/sampleparity/AndroidManifest.xml`: dedicated closest-to-sample manifest overlay (USB/BLE features, Wi-Fi/network/storage/location permissions, `largeHeap`, `org.apache.http.legacy`) used for the sample-parity APK.
- `android/app/src/main/AndroidManifest.xml`: declares Android Bluetooth runtime permissions (`BLUETOOTH_CONNECT`, `BLUETOOTH_SCAN`) required for printer discovery/cancel-discovery on Android 12+.
- `android/app/src/main/kotlin/com/example/xirja_frontend/BixolonSdkPrinter.kt`: Bixolon Android UPOS print session wrapper with sample-aligned lifecycle: main-thread SDK warm-up, persistent `BXLConfigLoader`/`jpos.POSPrinter`, listener registration, hard-wired sample printer model/logical name (`SPP-R310`), open/claim/enable session reuse across prints, 10s claim timeout, async output-complete waiting, device-service/runtime logging, and deep constructor/openFile/native-library diagnostics for crash analysis.
- `android/app/libs/bixolon`: vendored Bixolon Android UPOS SDK libs (`bixolon_printer_V2.2.10.jar`, `libcommon_V1.4.4.jar`).
- `android/app/src/main/jniLibs`: required Bixolon native runtime (`libbxl_common.so` for `armeabi-v7a`, `arm64-v8a`, `x86`, `x86_64`).
  - Also owns persistent printer debug log file creation/rotation at `Android/data/<applicationId>/files/logs/marnisi_printer_debug.log`.
- `lib/helpers/store_selection_helper.dart`: store dropdown option normalization and selected-store resolution for settings.
- `lib/helpers/settings_selection_helper.dart`: shared-preferences selected store/register compatibility (legacy + new keys).
- `lib/views/screens/sales_history_screen.dart`: local/deep-history search and reprint flow, including discounted subtotal/tax selection for reprints.
- `lib/helpers/sales_history_helper.dart`: sales-history filtering, cash-tendered calculations, and receipt subtotal/tax resolution helper for discounted prints.
- `lib/helpers/marnisi_image_helper.dart`: resolves backend/asset image paths, persists backend-driven login/dashboard background image paths, and builds cookie headers for private (`/private/files/...`) image URLs.
- `lib/helpers/marnisi_receipt_settings_helper.dart`: receipt print settings cache/parser (backend-driven from `Marnisi Settings` DocType with local defaults).
- `lib/views/widgets/marnisi_app_background.dart`: shared backend-controlled app background renderer (network/asset fallback + overlay) for non-login screens.
- `lib/views/screens/sales_history_screen.dart`: local/deep-history search and reprint flow.
- `lib/helpers/sales_history_helper.dart`: sales-history filtering + cash-tendered calculations.

## API Layer
- `lib/services/api_service.dart`: HTTP wrapper, timeout/offline handling, sales sync call.
- `lib/helpers/api_base_url_helper.dart`: normalizes host/URL input to origin and builds endpoint-safe API URLs.
- `lib/api_endpoints/routes_api.dart`: endpoint definitions used by POS and splash.
- `lib/services/marnisi_api_service.dart`: Marnisi v1 API client (auth context, vineyard items, packages, bookings).
  - Includes automatic one-time session re-auth retry on 403/permission/session errors using stored personal ID.
  - `get_context` payload now persists `receipt_settings`; explicit fetch endpoint is `xirja_marnisi.api.settings.get_receipt_settings`.
- `xirja_marnisi.api.auth.get_context` now returns `ui_assets` for backend-managed login/app backgrounds (sourced from `Vineyard` Attach Image fields).

## Marnisi Screens
- `lib/views/screens/inventory_screen.dart`: Item Management (vineyard-scoped item CRUD, stock controls, enable/disable, movement history).
- `lib/views/screens/tour_management_screen.dart`: Tour Packages + Bookings management (status transitions and check-in flow).
- `lib/views/screens/general_settings_screen.dart`, `lib/views/screens/inventory_screen.dart`, `lib/views/screens/sales_history_screen.dart`, `lib/views/screens/sales_register_pos_screen 2.dart`: backend-controlled app background via `lib/views/widgets/marnisi_app_background.dart`.
  - `general_settings_screen.dart` also includes `Run SDK Sample Print` action for isolated printer SDK verification.
- `lib/master_layout_config.dart`: Sidebar entries for `Item Management` and `Tour Management`.
- `lib/views/widgets/portal_master_layout/sidebar.dart`: role-based menu visibility using `xirja_marnisi.api.auth.get_context`.

## Tests
- `test/helpers/sales_pricing_calculator_test.dart`
- `test/helpers/payment_flow_helper_test.dart`
- `test/helpers/sales_history_helper_test.dart`
- `test/helpers/item_search_filter_helper_test.dart`
- `test/helpers/tour_register_helper_test.dart`
- `test/helpers/store_loyalty_policy_test.dart`
- `test/helpers/store_selection_helper_test.dart`
- `test/helpers/settings_selection_helper_test.dart`
- `test/helpers/marnisi_pos_restrictions_test.dart`
- `test/helpers/payment_method_display_helper_test.dart`
- `test/helpers/android_printer_discovery_test.dart`
- `test/android/bluetooth_permissions_source_test.dart`
- `test/android/bixolon_matrix_build_config_source_test.dart`
- `test/android/bixolon_matrix_manifest_overlay_source_test.dart`
- `test/android/bixolon_native_libs_source_test.dart`
- `test/android/build_info_logging_source_test.dart`
- `test/android/printer_background_dispatch_source_test.dart`
- `test/android/printer_sdk_throwable_guard_source_test.dart`
- `test/android/bixolon_sdk_detailed_logging_source_test.dart`
- `test/helpers/printer_debug_log_helper_test.dart`
- `test/helpers/marnisi_image_helper_test.dart`
- `test/helpers/loyalty_receipt_helper_test.dart`
- `test/helpers/app_build_info_test.dart`
- `test/helpers/portal_header_time_helper_test.dart`
- `test/helpers/pos_tablet_layout_helper_test.dart`
- `test/helpers/api_base_url_helper_test.dart`
- `test/services/api_service_test.dart`
- `test/services/printer_invoice_service_test.dart`
- `test/views/screens/general_settings_sdk_sample_source_test.dart`

## Single Test Trigger
- Run all frontend tests:
  - `flutter test`
