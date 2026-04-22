import 'package:flutter/material.dart';
import 'package:mobile_app/services/fine_service.dart';
import 'package:intl/intl.dart';
import '../../config/app_constants.dart';
import '../../widgets/driver/payment_history_card.dart';

class PaymentHistoryScreen extends StatefulWidget {
  const PaymentHistoryScreen({super.key});

  @override
  State<PaymentHistoryScreen> createState() => _PaymentHistoryScreenState();
}

class _PaymentHistoryScreenState extends State<PaymentHistoryScreen>
    with SingleTickerProviderStateMixin {
  final FineService _fineService = FineService();

  // ── Data ────────────────────────────────────────────────────────
  List<Map<String, dynamic>> _history = [];
  List<Map<String, dynamic>> _filteredHistory = [];
  bool _isLoading = true;

  // ── Search ──────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ── Filters ─────────────────────────────────────────────────────
  String _selectedDateFilter = 'All Time';
  String _selectedAmountFilter = 'Any Amount';
  String _selectedSortFilter = 'Newest First';

  // ── Shimmer animation ────────────────────────────────────────────
  late AnimationController _shimmerController;
  late Animation<double> _shimmerAnim;

  // ── Summary computeds ────────────────────────────────────────────
  double get _totalAmount => _filteredHistory.fold(
      0, (s, f) => s + (double.tryParse(f['amount'].toString()) ?? 0));

  String get _dateRange {
    if (_filteredHistory.isEmpty) return '—';
    final dates = _filteredHistory.map((f) {
      final raw = f['paidAt'] ?? f['updatedAt'] ?? DateTime.now().toIso8601String();
      return DateTime.parse(raw.toString());
    }).toList()
      ..sort();
    final fmt = DateFormat('MMM yyyy');
    return '${fmt.format(dates.first)} – ${fmt.format(dates.last)}';
  }

  // ── Filter chip options ───────────────────────────────────────────
  static const List<String> _dateOptions = [
    'All Time', 'Today', 'This Week', 'This Month', 'This Year'
  ];
  static const List<String> _amountOptions = [
    'Any Amount', 'Under LKR 1000', 'LKR 1000–5000', 'Over LKR 5000'
  ];
  static const List<String> _sortOptions = [
    'Newest First', 'Oldest First', 'Highest Amount', 'Lowest Amount'
  ];

  bool get _hasActiveFilters =>
      _selectedDateFilter != 'All Time' ||
      _selectedAmountFilter != 'Any Amount' ||
      _selectedSortFilter != 'Newest First';

  // ── Lifecycle ────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _shimmerAnim = Tween<double>(begin: -1.5, end: 1.5).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );
    _searchController.addListener(() {
      _searchQuery = _searchController.text;
      _applyFilters();
    });
    _loadHistory();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Data loading ─────────────────────────────────────────────────
  Future<void> _loadHistory() async {
    if (!mounted) return;

    // 1. Try loading from cache first for immediate display
    final cachedData = await _fineService.getPaidFinesFromCache();
    if (cachedData.isNotEmpty && mounted) {
      setState(() {
        _history = cachedData;
        _isLoading = false; // Stop shimmering since we have data
      });
      _applyFilters();
    }

    // 2. Fetch from network to ensure data is up to date
    // (Only set _isLoading if cache was empty)
    if (_history.isEmpty && mounted) {
      setState(() => _isLoading = true);
    }

    final networkData = await _fineService.getDriverPaidFines();
    
    if (mounted) {
      setState(() {
        if (networkData.isNotEmpty) {
          _history = networkData;
        }
        _isLoading = false;
      });
      _applyFilters();
    }
  }

  // ── Filter logic ──────────────────────────────────────────────────
  void _applyFilters() {
    List<Map<String, dynamic>> result = List.from(_history);
    final now = DateTime.now();
    final query = _searchQuery.toLowerCase().trim();

    // 1. Search
    if (query.isNotEmpty) {
      result = result.where((f) {
        final offense = (f['offenseName'] ?? '').toString().toLowerCase();
        final place = (f['place'] ?? '').toString().toLowerCase();
        final refId = (f['paymentId'] ?? '').toString().toLowerCase();
        final amount = (f['amount'] ?? '').toString().toLowerCase();
        return offense.contains(query) ||
            place.contains(query) ||
            refId.contains(query) ||
            amount.contains(query);
      }).toList();
    }

    // 2. Date filter
    if (_selectedDateFilter != 'All Time') {
      result = result.where((f) {
        final raw = f['paidAt'] ?? f['updatedAt'] ?? DateTime.now().toIso8601String();
        final dt = DateTime.parse(raw.toString());
        switch (_selectedDateFilter) {
          case 'Today':
            return dt.year == now.year &&
                dt.month == now.month &&
                dt.day == now.day;
          case 'This Week':
            final weekStart = now.subtract(Duration(days: now.weekday - 1));
            return dt.isAfter(
                DateTime(weekStart.year, weekStart.month, weekStart.day)
                    .subtract(const Duration(seconds: 1)));
          case 'This Month':
            return dt.year == now.year && dt.month == now.month;
          case 'This Year':
            return dt.year == now.year;
          default:
            return true;
        }
      }).toList();
    }

    // 3. Amount filter
    if (_selectedAmountFilter != 'Any Amount') {
      result = result.where((f) {
        final amt = double.tryParse(f['amount']?.toString() ?? '0') ?? 0;
        switch (_selectedAmountFilter) {
          case 'Under LKR 1000':
            return amt < 1000;
          case 'LKR 1000–5000':
            return amt >= 1000 && amt <= 5000;
          case 'Over LKR 5000':
            return amt > 5000;
          default:
            return true;
        }
      }).toList();
    }

    // 4. Sort
    result.sort((a, b) {
      switch (_selectedSortFilter) {
        case 'Oldest First':
          final da = DateTime.parse(
              (a['paidAt'] ?? a['updatedAt'] ?? DateTime.now().toIso8601String()).toString());
          final db = DateTime.parse(
              (b['paidAt'] ?? b['updatedAt'] ?? DateTime.now().toIso8601String()).toString());
          return da.compareTo(db);
        case 'Highest Amount':
          final aa = double.tryParse(a['amount']?.toString() ?? '0') ?? 0;
          final ba = double.tryParse(b['amount']?.toString() ?? '0') ?? 0;
          return ba.compareTo(aa);
        case 'Lowest Amount':
          final aa = double.tryParse(a['amount']?.toString() ?? '0') ?? 0;
          final ba = double.tryParse(b['amount']?.toString() ?? '0') ?? 0;
          return aa.compareTo(ba);
        case 'Newest First':
        default:
          final da = DateTime.parse(
              (a['paidAt'] ?? a['updatedAt'] ?? DateTime.now().toIso8601String()).toString());
          final db = DateTime.parse(
              (b['paidAt'] ?? b['updatedAt'] ?? DateTime.now().toIso8601String()).toString());
          return db.compareTo(da);
      }
    });

    setState(() => _filteredHistory = result);
  }

  void _clearFilters() {
    setState(() {
      _selectedDateFilter = 'All Time';
      _selectedAmountFilter = 'Any Amount';
      _selectedSortFilter = 'Newest First';
    });
    _applyFilters();
  }

  // ── Grouping ──────────────────────────────────────────────────────
  /// Returns a list of entries, each being either a header [String]
  /// or a `Map<String, dynamic>` fine item.
  List<dynamic> _buildGroupedList() {
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final f in _filteredHistory) {
      final raw = f['paidAt'] ?? f['updatedAt'] ?? DateTime.now().toIso8601String();
      final dt = DateTime.parse(raw.toString());
      final key = DateFormat('MMMM yyyy').format(dt);
      grouped.putIfAbsent(key, () => []).add(f);
    }
    final result = <dynamic>[];
    for (final entry in grouped.entries) {
      result.add(entry.key); // header string
      result.addAll(entry.value);
    }
    return result;
  }

  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Payment History',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: AppColors.primaryGreen,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // ── SUMMARY STRIP ──────────────────────────────────────
          if (!_isLoading) _buildSummaryStrip(),

          // ── SEARCH BAR ─────────────────────────────────────────
          if (!_isLoading) _buildSearchBar(),

          // ── FILTER CHIPS ───────────────────────────────────────
          if (!_isLoading) _buildFilterChips(),

          // ── RESULTS COUNT ──────────────────────────────────────
          if (!_isLoading && _history.isNotEmpty) _buildResultsCount(),

          // ── MAIN CONTENT ───────────────────────────────────────
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  // ── SUMMARY STRIP ─────────────────────────────────────────────────
  Widget _buildSummaryStrip() {
    final fmt = NumberFormat('#,##0', 'en_US');
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.md, horizontal: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground(context),
        borderRadius: BorderRadius.circular(AppRadius.medium),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            _summaryCell(
              '${_filteredHistory.length}',
              'Payments',
              Icons.receipt_long,
            ),
            const VerticalDivider(
                width: 1, thickness: 1, color: AppColors.divider),
            _summaryCell(
              'LKR ${fmt.format(_totalAmount)}',
              'Total Paid',
              Icons.payments_outlined,
            ),
            const VerticalDivider(
                width: 1, thickness: 1, color: AppColors.divider),
            _summaryCell(
              _dateRange,
              'Date Range',
              Icons.date_range,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCell(String value, String label, IconData icon) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AppColors.primaryGreen),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: AppTextSize.bodyMedium,
              color: AppTheme.textPrimary(context),
            ),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: AppTextSize.caption,
              color: AppTheme.textHint(context),
            ),
          ),
        ],
      ),
    );
  }

  // ── SEARCH BAR ────────────────────────────────────────────────────
  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.md, AppSpacing.md, 0),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by offense, location or ref ID...',
          hintStyle:
              TextStyle(color: AppTheme.textHint(context), fontSize: AppTextSize.bodyMedium),
          prefixIcon: Icon(Icons.search, color: AppTheme.textHint(context)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  color: AppTheme.textHint(context),
                  onPressed: () {
                    _searchController.clear();
                    _applyFilters();
                  },
                )
              : null,
          filled: true,
          fillColor: AppTheme.inputFill(context),
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: AppSpacing.md),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            borderSide: BorderSide(color: AppTheme.divider(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            borderSide: BorderSide(color: AppTheme.divider(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.medium),
            borderSide: const BorderSide(
                color: AppColors.primaryGreen, width: 1.5),
          ),
        ),
      ),
    );
  }

  // ── FILTER CHIPS ──────────────────────────────────────────────────
  Widget _buildFilterChips() {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.sm),
      child: SizedBox(
        height: 44,
        child: ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          children: [
            ..._dateOptions.map((o) => _filterChip(
                  label: o,
                  selected: _selectedDateFilter == o,
                  onTap: () {
                    setState(() => _selectedDateFilter = o);
                    _applyFilters();
                  },
                )),
            const SizedBox(width: 4),
            Container(width: 1, height: 24, color: AppColors.divider,
                margin: const EdgeInsets.symmetric(vertical: 10)),
            const SizedBox(width: 4),
            ..._amountOptions.map((o) => _filterChip(
                  label: o,
                  selected: _selectedAmountFilter == o,
                  onTap: () {
                    setState(() => _selectedAmountFilter = o);
                    _applyFilters();
                  },
                )),
            const SizedBox(width: 4),
            Container(width: 1, height: 24, color: AppColors.divider,
                margin: const EdgeInsets.symmetric(vertical: 10)),
            const SizedBox(width: 4),
            ..._sortOptions.map((o) => _filterChip(
                  label: o,
                  selected: _selectedSortFilter == o,
                  onTap: () {
                    setState(() => _selectedSortFilter = o);
                    _applyFilters();
                  },
                )),
            if (_hasActiveFilters) ...[
              const SizedBox(width: 8),
              Center(
                child: TextButton(
                  onPressed: _clearFilters,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: AppColors.dangerRed,
                  ),
                  child: const Text(
                    'Clear Filters',
                    style: TextStyle(fontSize: AppTextSize.bodySmall),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _filterChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.xs),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          height: 34,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm + 2, vertical: 0),
          decoration: BoxDecoration(
            color: selected ? AppColors.primaryGreen : AppTheme.cardBackground(context),
            borderRadius: BorderRadius.circular(AppRadius.circle),
            border: Border.all(
              color: selected ? AppColors.primaryGreen : AppTheme.divider(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                const Icon(Icons.check, size: 14, color: Colors.white),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                style: TextStyle(
                  fontSize: AppTextSize.bodySmall,
                  fontWeight:
                      selected ? FontWeight.w600 : FontWeight.normal,
                  color: selected ? Colors.white : AppTheme.textSecondary(context),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── RESULTS COUNT ─────────────────────────────────────────────────
  Widget _buildResultsCount() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppSpacing.md, AppSpacing.sm, AppSpacing.md, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          'Showing ${_filteredHistory.length} of ${_history.length} payments',
          style: TextStyle(
            fontSize: AppTextSize.bodySmall,
            color: AppTheme.textHint(context),
          ),
        ),
      ),
    );
  }

  // ── BODY ──────────────────────────────────────────────────────────
  Widget _buildBody() {
    if (_isLoading) return _buildShimmer();
    if (_history.isEmpty) return _buildEmptyState(_EmptyType.noData);
    if (_filteredHistory.isEmpty && _searchQuery.isNotEmpty) {
      return _buildEmptyState(_EmptyType.searchEmpty);
    }
    if (_filteredHistory.isEmpty && _hasActiveFilters) {
      return _buildEmptyState(_EmptyType.filterEmpty);
    }
    return _buildList();
  }

  // ── LIST WITH STICKY MONTH HEADERS ────────────────────────────────
  Widget _buildList() {
    final grouped = _buildGroupedList();
    return RefreshIndicator(
      color: AppColors.primaryGreen,
      onRefresh: _loadHistory,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.md, AppSpacing.md, AppSpacing.md, AppSpacing.md),
        itemCount: grouped.length,
        itemBuilder: (context, index) {
          final item = grouped[index];
          if (item is String) {
            // Count items in this group
            int count = 0;
            for (int i = index + 1; i < grouped.length; i++) {
              if (grouped[i] is String) break;
              count++;
            }
            return _buildMonthHeader(item, count);
          }
          return PaymentHistoryCard(fine: item as Map<String, dynamic>);
        },
      ),
    );
  }

  Widget _buildMonthHeader(String month, int count) {
    return Padding(
      padding: const EdgeInsets.only(
          top: AppSpacing.sm, bottom: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppTheme.divider(context), thickness: 1)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Text(
              '$month  ·  $count ${count == 1 ? 'payment' : 'payments'}',
              style: TextStyle(
                fontSize: 11,
                color: AppTheme.textHint(context),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ),
          Expanded(child: Divider(color: AppTheme.divider(context), thickness: 1)),
        ],
      ),
    );
  }

  // ── EMPTY STATES ──────────────────────────────────────────────────
  Widget _buildEmptyState(_EmptyType type) {
    IconData icon;
    String title;
    String subtitle;
    String? btnLabel;
    VoidCallback? btnAction;

    switch (type) {
      case _EmptyType.noData:
        icon = Icons.receipt_long;
        title = 'No Payments Yet';
        subtitle = 'Your paid fine history will appear here';
        break;
      case _EmptyType.searchEmpty:
        icon = Icons.search_off;
        title = 'No Results Found';
        subtitle = 'No payments match "$_searchQuery"';
        btnLabel = 'Clear Search';
        btnAction = () => _searchController.clear();
        break;
      case _EmptyType.filterEmpty:
        icon = Icons.filter_list_off;
        title = 'No Matching Payments';
        subtitle = 'Try adjusting your filters';
        btnLabel = 'Reset Filters';
        btnAction = _clearFilters;
        break;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 80, color: Colors.grey[350]),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            style: TextStyle(
              fontSize: AppTextSize.bodyLarge,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary(context),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
            child: Text(
              subtitle,
              style: TextStyle(
                  fontSize: AppTextSize.bodyMedium, color: AppTheme.textHint(context)),
              textAlign: TextAlign.center,
            ),
          ),
          if (btnLabel != null && btnAction != null) ...[
            const SizedBox(height: AppSpacing.md),
            OutlinedButton(
              onPressed: btnAction,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryGreen,
                side: const BorderSide(color: AppColors.primaryGreen),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppRadius.medium)),
              ),
              child: Text(btnLabel),
            ),
          ],
        ],
      ),
    );
  }

  // ── SHIMMER SKELETON ──────────────────────────────────────────────
  Widget _buildShimmer() {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (context, child) {
        return ListView.builder(
          padding: const EdgeInsets.all(AppSpacing.md),
          itemCount: 3,
          itemBuilder: (_, __) => _shimmerCard(),
        );
      },
    );
  }

  Widget _shimmerCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground(context),
        borderRadius: BorderRadius.circular(AppRadius.large),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Accent bar shimmer
          _shimmerBox(height: 4, width: double.infinity, radius: 0),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  _shimmerBox(height: 36, width: 36, radius: 100),
                  const SizedBox(width: AppSpacing.sm),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _shimmerBox(height: 14, width: 150),
                      const SizedBox(height: 6),
                      _shimmerBox(height: 11, width: 90),
                    ],
                  ),
                ]),
                const SizedBox(height: AppSpacing.md),
                _shimmerBox(height: 1, width: double.infinity, radius: 0),
                const SizedBox(height: AppSpacing.md),
                _shimmerBox(height: 11, width: 110),
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Expanded(child: _shimmerBox(height: 60)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _shimmerBox(height: 60)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _shimmerBox(height: 60)),
                ]),
                const SizedBox(height: AppSpacing.md),
                _shimmerBox(height: 11, width: 110),
                const SizedBox(height: AppSpacing.sm),
                Row(children: [
                  Expanded(child: _shimmerBox(height: 60)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _shimmerBox(height: 60)),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(child: _shimmerBox(height: 60)),
                ]),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shimmerBox({
    required double height,
    double? width,
    double radius = 6,
  }) {
    return AnimatedBuilder(
      animation: _shimmerAnim,
      builder: (context, _) {
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(radius),
            gradient: LinearGradient(
              begin: Alignment(_shimmerAnim.value - 1, 0),
              end: Alignment(_shimmerAnim.value, 0),
              colors: Theme.of(context).brightness == Brightness.dark
                  ? const [
                      Color(0xFF2A2A2A),
                      Color(0xFF3A3A3A),
                      Color(0xFF2E2E2E),
                      Color(0xFF3A3A3A),
                      Color(0xFF2A2A2A),
                    ]
                  : const [
                      Color(0xFFEEEEEE),
                      Color(0xFFF5F5F5),
                      Color(0xFFE0E0E0),
                      Color(0xFFF5F5F5),
                      Color(0xFFEEEEEE),
                    ],
              stops: const [0.0, 0.35, 0.5, 0.65, 1.0],
            ),
          ),
        );
      },
    );
  }
}

// ── Enum for empty state ───────────────────────────────────────────
enum _EmptyType { noData, searchEmpty, filterEmpty }
