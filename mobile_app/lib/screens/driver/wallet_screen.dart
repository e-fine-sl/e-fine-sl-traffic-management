// lib/screens/driver/wallet_screen.dart
import 'package:flutter/material.dart';
import '../../config/app_constants.dart';
import '../../models/wallet_model.dart';
import '../../services/wallet_service.dart';
import '../../widgets/wallet/wallet_identity_card.dart';
import '../../widgets/wallet/vehicle_selector_tab.dart';
import '../../widgets/wallet/emission_cert_card.dart';
import '../../widgets/wallet/insurance_cert_card.dart';
import '../../widgets/wallet/revenue_license_card.dart';
import '../../widgets/wallet/wallet_summary_banner.dart';
import '../../widgets/wallet/wallet_skeleton_loader.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  final _walletService = WalletService();

  WalletModel? _wallet;
  bool _isLoading = true;
  bool _isLoaded = false;
  String? _errorMessage;
  int _selectedVehicleIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  // ── Load Wallet ─────────────────────────────────────────
  Future<void> _loadWallet({bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final wallet = await _walletService.getWallet(forceRefresh: forceRefresh);
      if (mounted) {
        setState(() {
          _wallet = wallet;
          _isLoaded = true;
          _isLoading = false;
          _selectedVehicleIndex = 0;
        });
      }
    } on WalletException catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.message;
          _isLoading = false;
          _isLoaded = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Connection failed. Check your internet.';
          _isLoading = false;
          _isLoaded = false;
        });
      }
    }
  }

  void _selectVehicle(int index) {
    setState(() => _selectedVehicleIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const WalletSkeletonLoader();
    if (_isLoaded && _wallet != null) return _buildWalletView();
    return _buildErrorView();
  }

  // ══════════════════════════════════════════════════════
  // ERROR VIEW
  // ══════════════════════════════════════════════════════
  Widget _buildErrorView() {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.primaryGreen),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFE8F5E9), Colors.white],
            stops: [0.0, 0.55],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    color: AppColors.errorRed.withAlpha(20),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.error_outline,
                      color: AppColors.errorRed, size: 44),
                ),
                const SizedBox(height: AppSpacing.lg),
                const Text('Wallet Load Failed',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary)),
                const SizedBox(height: AppSpacing.sm),
                Text(_errorMessage ?? 'Unknown error occurred.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
                const SizedBox(height: AppSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    onPressed: () => _loadWallet(forceRefresh: true),
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    label: const Text('Try Again',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.medium),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════
  // WALLET LOADED VIEW
  // ══════════════════════════════════════════════════════
  Widget _buildWalletView() {
    final wallet = _wallet!;
    final vehicle = wallet.vehicles.isNotEmpty
        ? wallet.vehicles[_selectedVehicleIndex]
        : null;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('My Digital Wallet',
            style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(), // Just pop the screen
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => _loadWallet(forceRefresh: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadWallet(forceRefresh: true),
        color: AppColors.primaryGreen,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.md),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // 1. Summary Banner
                  WalletSummaryBanner(summary: wallet.summary),
                  const SizedBox(height: AppSpacing.md),

                  // 2. Identity Card
                  WalletIdentityCard(wallet: wallet),
                  const SizedBox(height: AppSpacing.md),

                  // 3. Vehicle Selector (only if >1)
                  if (wallet.vehicles.length > 1) ...[
                    VehicleSelectorTab(
                      vehicles: wallet.vehicles,
                      selectedIndex: _selectedVehicleIndex,
                      onVehicleSelected: _selectVehicle,
                    ),
                    const SizedBox(height: AppSpacing.md),
                  ],

                  // 4. Documents for selected vehicle
                  if (vehicle != null) ...[
                    EmissionCertCard(
                      emission: vehicle.documents.emission,
                      registrationNo: vehicle.registrationNo,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    InsuranceCertCard(
                      insurance: vehicle.documents.insurance,
                      registrationNo: vehicle.registrationNo,
                    ),
                    const SizedBox(height: AppSpacing.md),
                    RevenueLicenseCard(
                      revenueLicense: vehicle.documents.revenueLicense,
                      registrationNo: vehicle.registrationNo,
                    ),
                  ],
                  const SizedBox(height: 32),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
