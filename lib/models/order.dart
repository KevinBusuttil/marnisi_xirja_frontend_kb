// class manage order info vars
class Order {
  int saleId = 0;
  String prefix = '';
  String cashierCode = '';
  String orderNumber = '';
  double subTotal = 0.00;
  int lines = 0;
  double tax = 0.00;
  double total = 0.00;
  double change = 0.0;
  double balance = 0.0;
  String paymentMethodId = '';
  String paymentMthdsTxnNames = '';
  List<Map<String, dynamic>> payMthdsCache = [];
  double discount = 0.00;
  double discountPct = 0.00;
  double loyaltyPointsUsed = 0.0;
  double loyaltyPointsEarned = 0.0;
  double loyaltyPointsBalance = 0.0;

  Order();
}
