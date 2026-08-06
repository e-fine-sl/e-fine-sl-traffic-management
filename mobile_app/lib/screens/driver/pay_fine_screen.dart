import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/api_logger.dart' as http;
import 'package:mobile_app/services/fine_service.dart';
import 'dart:convert';
import 'package:payhere_mobilesdk_flutter/payhere_mobilesdk_flutter.dart';
import '../../config/app_constants.dart';

class PayFineScreen extends StatefulWidget {
  final Map<String, dynamic> fine;

  const PayFineScreen({super.key, required this.fine});

  @override
  State<PayFineScreen> createState() => _PayFineScreenState();
}

class _PayFineScreenState extends State<PayFineScreen> {
  
  // PayHere Sandbox Credentials
  final String _merchantId = "1232005"; 
  // Secret is now handled in Backend via Hash


  @override
  Widget build(BuildContext context) {
    double amount = double.tryParse(widget.fine['amount'].toString()) ?? 0.0;
    String offense = widget.fine['offenseName'] ?? "Traffic Fine";
    String fineId = widget.fine['_id'] ?? "Unknown ID";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Pay Fine", style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryGreenDark,
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bill Card
            Container(
              width: double.infinity,
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
                   const Icon(Icons.receipt_long, size: 50, color: AppColors.primaryGreen),
                   const SizedBox(height: 10),
                   Text(offense, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                   const SizedBox(height: 20),
                   const Divider(),
                   const SizedBox(height: 10),
                   _buildRow("Fine ID", fineId.substring(0, 8).toUpperCase()),
                   _buildRow("Date", (widget.fine['createdAt'] ?? "").toString().substring(0, 10)),
                   _buildRow("Vehicle", widget.fine['vehicleNumber'] ?? "N/A"),
                   
                   const SizedBox(height: 20),
                   const Divider(),
                   const SizedBox(height: 10),
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       const Text("Total Amount", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                       Text("LKR ${amount.toStringAsFixed(2)}", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primaryGreen)),
                     ],
                   )
                ],
              ),
            ),
            const Spacer(),
            
            // Pay Button
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: () => _startPayHerePayment(amount, offense, fineId),
                icon: const Icon(Icons.payment, color: Colors.white), 
                label: const Text("PAY NOW (PayHere)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Download e-Fine Receipt Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: () => _downloadFinePdf(fineId),
                icon: const Icon(Icons.picture_as_pdf, color: AppColors.primaryGreen),
                label: const Text("Download e-Fine Receipt (PDF)", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.primaryGreen)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.primaryGreen, width: 1.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 15),
          ],
        ),
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
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 16)),
        ],
      ),
    );
  }

  Future<void> _downloadFinePdf(String fineId) async {
    final Uri url = Uri.parse('${ApiConstants.baseUrl}/fines/$fineId/pdf');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open e-Fine receipt PDF URL.')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error downloading receipt: $e')),
      );
    }
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
        
        bool success = await FineService().payFine(widget.fine['_id'], paymentId);

        if (!mounted) return; // Check mounted

        if (success) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fine Paid Successfully!"), backgroundColor: AppColors.successGreen));
           // Pop with Result TRUE to refresh previous screen
           Navigator.pop(context, true); 
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
