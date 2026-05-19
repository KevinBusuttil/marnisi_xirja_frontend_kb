class PrinterPortManager {
  void initializeComPort() {}

  void closeComPort() {}

  bool openPrinter(String printerName) => false;

  bool startDocument() => false;

  bool startPage() => false;

  bool writeData(List<int> dataBytes) => false;

  bool endPage() => false;

  bool endDocument() => false;

  void closePrinter() {}

  void freeResources(List<dynamic> resources) {}
}
