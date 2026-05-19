import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart';

/// class PrinterPortManager manage printer provide for win32 api c++
/// * [hPrinter] pointer manage memory
/// * [pPrinterName] get printer name
/// * [pDocName] doc to process
/// * [docInfo] represent doc structure
class PrinterPortManager {
  late Pointer<HANDLE> hPrinter;
  late Pointer<Utf16> pPrinterName;
  late Pointer<Utf16> pDocName;
  late Pointer<DOC_INFO_1> docInfo;

  void initializeComPort() {
    CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  }

  void closeComPort() {
    CoUninitialize();
  }

  bool openPrinter(String printerName) {
    hPrinter = calloc<HANDLE>();
    pPrinterName = TEXT(printerName);
    pDocName = TEXT('invoice');
    docInfo = calloc<DOC_INFO_1>()
      ..ref.pDocName = pDocName
      ..ref.pOutputFile = nullptr
      ..ref.pDatatype = nullptr;

    return OpenPrinter(pPrinterName, hPrinter, nullptr) != 0;
  }

  bool startDocument() {
    return StartDocPrinter(hPrinter.value, 1, docInfo) != 0;
  }

  bool startPage() {
    return StartPagePrinter(hPrinter.value) != 0;
  }

  bool writeData(List<int> dataBytes) {
    final dataPointer = calloc<BYTE>(dataBytes.length);
    for (var i = 0; i < dataBytes.length; i++) {
      dataPointer[i] = dataBytes[i];
    }
    final written = calloc<DWORD>();
    final result = WritePrinter(
          hPrinter.value,
          dataPointer.cast<Void>(),
          dataBytes.length,
          written,
        ) !=
        0;
    free(dataPointer);
    free(written);
    return result;
  }

  bool endPage() {
    return EndPagePrinter(hPrinter.value) != 0;
  }

  bool endDocument() {
    return EndDocPrinter(hPrinter.value) != 0;
  }

  void closePrinter() {
    ClosePrinter(hPrinter.value);
    free(pPrinterName);
    free(pDocName);
    free(docInfo);
    free(hPrinter);
  }

  void freeResources(List<Pointer> resources) {
    for (var resource in resources) {
      free(resource);
    }
  }
}
