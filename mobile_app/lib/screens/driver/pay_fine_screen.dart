import 'package:flutter/material.dart';
import '../../services/api_logger.dart' as http;
import 'package:mobile_app/services/fine_service.dart';
import 'dart:convert';
import 'package:payhere_mobilesdk_flutter/payhere_mobilesdk_flutter.dart';
import '../../config/app_constants.dart';

class PayFineScreen extends StatefulWidget {
  final Map<String, dynamic>? fine;
  final List<Map<String, dynamic>>? fines;

  const PayFineScreen({super.key, this.fine, this.fines});

  @override
  State<PayFineScreen> createState() => _PayFineScreenState();
}

class _PayFineScreenState extends State<PayFineScreen> {
  final FineService _fineService = FineService();

  // PayHere Sandbox Credentials
  final String _merchantId = "1232005";
  // Secret is now handled in Backend via Hash

  List<Map<String, dynamic>> _fines = [];
  bool _isLoading = true;
  bool _hasPaidAny = false;

  double get _totalPendingAmount => _fines.fold(
        0.0,
        (sum, f) => sum + (double.tryParse(f['amount']?.toString() ?? '0') ?? 0.0),
      );

  @override
  void initState() {
    super.initState();
    if (widget.fines != null && widget.fines!.isNotEmpty) {
      _fines = _orderFines(List<Map<String, dynamic>>.from(widget.fines!));
      _isLoading = false;
    } else if (widget.fine != null) {
      _fines = [widget.fine!];
      _isLoading = false;
    }
    _loadPendingFines();
  }

  List<Map<String, dynamic>> _orderFines(List<Map<String, dynamic>> list) {
    if (widget.fine != null && widget.fine!['_id'] != null) {
      final String targetId = widget.fine!['_id'].toString();
      final selected = list.where((f) => f['_id']?.toString() == targetId).toList();
      final others = list.where((f) => f['_id']?.toString() != targetId).toList();
      return [...selected, ...others];
    }
    return list;
  }

  Future<void> _loadPendingFines() async {
    try {
      final fetched = await _fineService.getDriverPendingFines();
      if (!mounted) return;
      setState(() {
        if (fetched.isNotEmpty) {
          _fines = _orderFines(fetched);
        } else if (widget.fine == null) {
          _fines = [];
        }
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        Navigator.pop(context, result ?? _hasPaidAny);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Pay Fines", style: TextStyle(color: Colors.white)),
          backgroundColor: AppColors.primaryGreenDark,
          foregroundColor: Colors.white,
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white),
              onPressed: () {
                setState(() => _isLoading = true);
                _loadPendingFines();
              },
            ),
          ],
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: AppColors.primaryGreen),
              )
            : _fines.isEmpty
                ? _buildEmptyState()
                : Column(
                    children: [
                      _buildSummaryBanner(),
                      Expanded(
                        child: RefreshIndicator(
                          color: AppColors.primaryGreen,
                          onRefresh: _loadPendingFines,
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                            itemCount: _fines.length,
                            itemBuilder: (context, index) {
                              return _buildFineCard(_fines[index], index);
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildSummaryBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(20, 16, 20, 4),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGreen.withAlpha(80)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long, color: AppColors.primaryGreen, size: 22),
              const SizedBox(width: 8),
              Text(
                "${_fines.length} Pending ${_fines.length == 1 ? 'Fine' : 'Fines'}",
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            "Total: LKR ${_totalPendingAmount.toStringAsFixed(2)}",
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryGreenDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_outline, size: 72, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              "No Pending Fines",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "You have no unpaid traffic fines at this time.",
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFineCard(Map<String, dynamic> fine, int index) {
    final double amount = double.tryParse(fine['amount']?.toString() ?? '0') ?? 0.0;
    final String offense = (fine['offenseName'] ?? "Traffic Fine").toString();
    final String fineId = (fine['_id'] ?? "Unknown ID").toString();
    final String displayId = fineId.length >= 8
        ? fineId.substring(0, 8).toUpperCase()
        : fineId.toUpperCase();
    final String rawDate = (fine['date'] ?? fine['createdAt'] ?? "").toString();
    final String displayDate = rawDate.length >= 10
        ? rawDate.substring(0, 10)
        : (rawDate.isNotEmpty ? rawDate : "N/A");
    final String vehicle = (fine['vehicleNumber'] ?? "N/A").toString();
    final String place = (fine['place'] ?? "").toString();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.grey.withAlpha(26), blurRadius: 10, spreadRadius: 2)
        ],
        border: Border.all(color: Colors.green.withAlpha(76)),
      ),
      child: Column(
        children: [
          const Icon(Icons.receipt_long, size: 46, color: AppColors.primaryGreen),
          const SizedBox(height: 10),
          Text(
            offense,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 8),
          _buildRow("Fine ID", displayId),
          _buildRow("Date", displayDate),
          _buildRow("Vehicle", vehicle),
          if (place.isNotEmpty) _buildRow("Location", place),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                "Total Amount",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                "LKR ${amount.toStringAsFixed(2)}",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryGreen,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Pay Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton.icon(
              onPressed: () => _startPayHerePayment(amount, offense, fineId),
              icon: const Icon(Icons.payment, color: Colors.white),
              label: const Text(
                "PAY NOW (PayHere)",
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Download e-Fine Receipt Button (Before paying the fine)
          SizedBox(
            width: double.infinity,
            height: 46,
            child: OutlinedButton.icon(
              onPressed: () => _downloadFinePdf(fineId),
              icon: const Icon(Icons.picture_as_pdf, color: AppColors.primaryGreen),
              label: const Text(
                "Download e-Fine Receipt (PDF)",
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryGreen,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadFinePdf(String fineId) async {
    await _fineService.downloadFineReceiptPdf(context, fineId);
  }

  Future<void> _startPayHerePayment(double amount, String item, String orderId) async {
    
    // 1. Fetch Hash from Backend
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Initializing Secure Payment...")));
    
    String? hash = await _getPayHereHash(orderId, amount);

    if (!mounted) return; // Check mounted

    if (hash == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Security Error: Could not generate hash."), backgroundColor: AppColors.errorRed));
      return;
    }

    // 2. Start Payment
    Map paymentObject = {
      "sandbox": true,                 
      "merchant_id": _merchantId,      
      // "merchant_secret": NO LONGER NEEDED HERE
      "notify_url": "${ApiConstants.baseUrl}/fines/payment_notify", 
      "order_id": orderId,             
      "items": item,                   
      "amount": amount.toStringAsFixed(2), 
      "currency": "LKR",
      "hash": hash, // <-- The Secure Hash from Backend               
      "first_name": "Saman",           
      "last_name": "Perera",
      "email": "samanp@gmail.com",
      "phone": "0771234567",
      "address": "No.1, Galle Road",
      "city": "Colombo",
      "country": "Sri Lanka",
      "delivery_address": "No. 46, Galle road, Kalutara South",
      "delivery_city": "Kalutara",
      "delivery_country": "Sri Lanka",
      "custom_1": "",
      "custom_2": ""
    };

    debugPrint("---------------- PAYHERE DEBUG ----------------");
    debugPrint("Merchant ID: $_merchantId");
    debugPrint("Order ID: $orderId");
    debugPrint("Hash: $hash");
    debugPrint("-----------------------------------------------");

    PayHere.startPayment(
      paymentObject, 
      (paymentId) async {
        debugPrint("PayHere Success: $paymentId");
        
        // Call Backend to update Fine Status
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Updating payment status...")));
        
        bool success = await _fineService.payFine(orderId, paymentId);

        if (!mounted) return; // Check mounted

        if (success) {
           _hasPaidAny = true;
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fine Paid Successfully!"), backgroundColor: AppColors.successGreen));
           setState(() {
             _fines.removeWhere((f) => f['_id']?.toString() == orderId);
           });
           if (_fines.isEmpty) {
             // Pop with Result TRUE to refresh previous screen when all fines are paid
             Navigator.pop(context, true);
           } else {
             await _loadPendingFines();
           }
        } else {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment noted, but status update failed. Please contact support."), backgroundColor: AppColors.warningOrange));
        }
      }, 
      (error) {
        debugPrint("PayHere Error: $error");
        // Error
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Payment Failed: $error"), backgroundColor: AppColors.errorRed));
      }, 
      () {
        // Dismissed
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Payment Dismissed")));
      }
    );
  }

  Future<String?> _getPayHereHash(String orderId, double amount) async {
      try {

        final apiUrl = Uri.parse('${ApiConstants.baseUrl}/payment/hash');

        final response = await http.post(
          apiUrl,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            "order_id": orderId,
            "amount": amount,
            "currency": "LKR"
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['hash'];
        } else {
           debugPrint("Hash Error: ${response.body}");
           return null;
        }
      } catch (e) {
        debugPrint("Hash Exception: $e");
        return null;
      }
  }
}
