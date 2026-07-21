import '../json_helpers.dart';

class AdvanceTransaction {
  AdvanceTransaction({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    this.paymentMode,
    this.referenceNumber,
    this.notes,
    this.visitId,
    this.invoiceId,
    this.createdAt,
  });

  final int id;
  final int customerId;
  final String type; // receive | apply | refund
  final double amount;
  final double balanceAfter;
  final String? paymentMode;
  final String? referenceNumber;
  final String? notes;
  final int? visitId;
  final int? invoiceId;
  final String? createdAt;

  factory AdvanceTransaction.fromJson(Map<String, dynamic> j) =>
      AdvanceTransaction(
        id: intOrNull(j['id']) ?? 0,
        customerId: intOrNull(j['customer_id']) ?? 0,
        type: j['type']?.toString() ?? 'receive',
        amount: numOrNull(j['amount']) ?? 0,
        balanceAfter: numOrNull(j['balance_after']) ?? 0,
        paymentMode: j['payment_mode']?.toString(),
        referenceNumber: j['reference_number']?.toString(),
        notes: j['notes']?.toString(),
        visitId: intOrNull(j['visit_id']),
        invoiceId: intOrNull(j['invoice_id']),
        createdAt: j['created_at']?.toString(),
      );
}
