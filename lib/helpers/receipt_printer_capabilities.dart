class ReceiptPrinterCapabilities {
  final bool supportsCutter;
  final bool supportsCashDrawer;
  final int lineWidth;

  const ReceiptPrinterCapabilities({
    required this.supportsCutter,
    required this.supportsCashDrawer,
    required this.lineWidth,
  });
}

/// SPP-R310 is a mobile Bluetooth printer with no cutter and no cash drawer.
const sppR310Capabilities = ReceiptPrinterCapabilities(
  supportsCutter: false,
  supportsCashDrawer: false,
  lineWidth: 48,
);

/// Windows native printer typically supports paper cutter and cash drawer.
const windowsNativeCapabilities = ReceiptPrinterCapabilities(
  supportsCutter: true,
  supportsCashDrawer: true,
  lineWidth: 48,
);
