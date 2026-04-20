import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../../services/fine_service.dart';
import '../../config/app_constants.dart';

class FineHistoryScreen extends StatefulWidget {
  const FineHistoryScreen({super.key});

  @override
  State<FineHistoryScreen> createState() => _FineHistoryScreenState();
}

class _FineHistoryScreenState extends State<FineHistoryScreen> {
  final FineService _fineService = FineService();
  List<Map<String, dynamic>> _fines = [];
  bool _isLoading = true;
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  Future<void> _fetchHistory() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    try {
      final history = await _fineService.getOfficerFineHistory();
      if (mounted) {
        setState(() {
          _fines = history;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll("Exception:", "").trim();
          _isLoading = false;
        });
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) {
      return 'police.history_unknown_date'.tr();
    }
    try {
      return DateFormat('yyyy-MM-dd – hh:mm a').format(DateTime.parse(dateStr));
    } catch (e) {
      return dateStr;
    }
  }

  /// Maps raw status string to a localized label.
  String _localizedStatus(String raw) {
    switch (raw.toLowerCase()) {
      case 'paid':
        return 'police.history_status_paid'.tr();
      case 'unpaid':
        return 'police.history_status_unpaid'.tr();
      default:
        return 'police.history_status_pending'.tr();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text('police.history_appbar_title'.tr()),
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchHistory,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.errorRed, size: 60),
                        const SizedBox(height: 10),
                        Text(
                          'police.history_failed_title'.tr(),
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 5),
                        Text(_errorMessage,
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey)),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _fetchHistory,
                          icon: const Icon(Icons.refresh),
                          label: Text('police.history_retry'.tr()),
                        )
                      ],
                    ),
                  ),
                )
              : _fines.isEmpty
                  ? Center(child: Text('police.history_empty'.tr()))
                  : ListView.builder(
                      padding: const EdgeInsets.all(15),
                      itemCount: _fines.length,
                      itemBuilder: (context, index) {
                        final fine = _fines[index];

                        final license = fine['licenseNumber'] ?? "N/A";
                        final vehicle = fine['vehicleNumber'] ?? "N/A";
                        final offense = fine['offenseName'] ??
                            'police.history_violation'.tr();
                        final place = fine['place'] ??
                            'police.history_unknown_location'.tr();
                        final amount = fine['amount']?.toString() ?? "0";
                        final rawStatus = fine['status'] ?? "pending";
                        final localizedStatus = _localizedStatus(rawStatus);
                        final dateStr = fine['date'];

                        final bool isPaid =
                            rawStatus.toString().toLowerCase() == 'paid';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 15),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(15)),
                          elevation: 3,
                          child: Padding(
                            padding: const EdgeInsets.all(15),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        offense,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: AppColors.primaryBlue),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isPaid
                                            ? Colors.green[100]
                                            : Colors.orange[100],
                                        borderRadius:
                                            BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        localizedStatus,
                                        style: TextStyle(
                                          color: isPaid
                                              ? Colors.green[800]
                                              : Colors.orange[800],
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                        ),
                                      ),
                                    )
                                  ],
                                ),
                                const SizedBox(height: 10),

                                Row(
                                  children: [
                                    const Icon(Icons.credit_card,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 5),
                                    Text(
                                      "${'police.history_lic_prefix'.tr()} $license",
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(width: 15),
                                    const Icon(Icons.directions_car,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 5),
                                    Text(vehicle,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w500)),
                                  ],
                                ),

                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 5),
                                    Expanded(
                                        child: Text(place,
                                            style: const TextStyle(
                                                color: Colors.grey))),
                                  ],
                                ),

                                const SizedBox(height: 5),
                                Row(
                                  children: [
                                    const Icon(Icons.access_time,
                                        size: 16, color: Colors.grey),
                                    const SizedBox(width: 5),
                                    Text(_formatDate(dateStr),
                                        style: const TextStyle(
                                            color: Colors.grey, fontSize: 12)),
                                  ],
                                ),

                                const Divider(),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: Text(
                                    "${'police.history_amount_prefix'.tr()}$amount",
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: AppColors.errorRed),
                                  ),
                                )
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}