import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../data/wallet_repository.dart';
import '../models/wallet_transaction.dart';

final _currencyFormat = NumberFormat.currency(
  locale: 'th_TH',
  symbol: '฿',
  decimalDigits: 2,
);
final _dateFormat = DateFormat('d MMM yyyy', 'th_TH');
const _incomeColor = Color(0xFF079C79);
const _expenseColor = Color(0xFFE67E52);
bool _isCompactLayout(BuildContext context) =>
    MediaQuery.sizeOf(context).width < 400;

const _categoryColors = [
  Color(0xFF087F70),
  Color(0xFF78B7A5),
  Color(0xFFF0A66B),
  Color(0xFFE36F61),
  Color(0xFF8A83C6),
  Color(0xFF5C9BD1),
  Color(0xFFC5A84A),
  Color(0xFF77915E),
];

class WalletShell extends StatefulWidget {
  const WalletShell({
    required this.controller,
    required this.isDark,
    required this.onThemeChanged,
    super.key,
  });

  final WalletController controller;
  final bool isDark;
  final ValueChanged<bool> onThemeChanged;

  @override
  State<WalletShell> createState() => _WalletShellState();
}

class _WalletShellState extends State<WalletShell> {
  int _selectedIndex = 0;

  Future<void> _openEditor([WalletTransaction? transaction]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      builder: (context) => TransactionEditor(
        controller: widget.controller,
        transaction: transaction,
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('บันทึกรายการเรียบร้อยแล้ว')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardScreen(
        controller: widget.controller,
        onAdd: () => _openEditor(),
      ),
      HistoryScreen(controller: widget.controller, onEdit: _openEditor),
      ReportsScreen(controller: widget.controller),
      SettingsScreen(
        isDark: widget.isDark,
        onThemeChanged: widget.onThemeChanged,
      ),
    ];
    return Scaffold(
      body: SafeArea(child: pages[_selectedIndex]),
      floatingActionButton: _selectedIndex == 3
          ? null
          : _isCompactLayout(context)
          ? FloatingActionButton.small(
              tooltip: 'เพิ่มรายการ',
              onPressed: () => _openEditor(),
              child: const Icon(Icons.add_rounded),
            )
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('เพิ่มรายการ'),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.space_dashboard_outlined),
            selectedIcon: Icon(Icons.space_dashboard_rounded),
            label: 'ภาพรวม',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'รายการ',
          ),
          NavigationDestination(
            icon: Icon(Icons.pie_chart_outline_rounded),
            selectedIcon: Icon(Icons.pie_chart_rounded),
            label: 'วิเคราะห์',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_rounded),
            selectedIcon: Icon(Icons.tune_rounded),
            label: 'ตั้งค่า',
          ),
        ],
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({
    required this.controller,
    required this.onAdd,
    super.key,
  });

  final WalletController controller;
  final VoidCallback onAdd;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  _Period _period = _Period.month;

  List<WalletTransaction> get _filtered => widget.controller.transactions
      .where((item) => _inPeriod(item.date))
      .toList();

  bool _inPeriod(DateTime date) {
    final now = DateTime.now();
    if (_period == _Period.today) {
      return date.year == now.year &&
          date.month == now.month &&
          date.day == now.day;
    }
    if (_period == _Period.week) {
      final start = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));
      final end = start.add(const Duration(days: 7));
      return !date.isBefore(start) && date.isBefore(end);
    }
    return date.year == now.year && date.month == now.month;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        if (widget.controller.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }
        if (widget.controller.loadError != null) {
          return _LoadError(
            error: widget.controller.loadError!,
            onRetry: widget.controller.load,
          );
        }
        final items = _filtered;
        final income = items
            .where((item) => item.isIncome)
            .fold<double>(0, (total, item) => total + item.amount);
        final expenses = items
            .where((item) => !item.isIncome)
            .fold<double>(0, (total, item) => total + item.amount);
        final compact = _isCompactLayout(context);
        return RefreshIndicator(
          onRefresh: widget.controller.load,
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              compact ? 16 : 20,
              compact ? 10 : 16,
              compact ? 16 : 20,
              compact ? 76 : 108,
            ),
            children: [
              _GreetingHeader(),
              SizedBox(height: compact ? 12 : 22),
              _BalanceCard(
                income: income,
                expenses: expenses,
                compact: compact,
                periodLabel: switch (_period) {
                  _Period.today => 'วันนี้',
                  _Period.week => 'สัปดาห์นี้',
                  _Period.month => 'เดือนนี้',
                },
              ),
              SizedBox(height: compact ? 14 : 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'สรุปการเงิน',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  DropdownButton<_Period>(
                    value: _period,
                    isDense: true,
                    iconSize: compact ? 18 : 24,
                    underline: const SizedBox.shrink(),
                    padding: EdgeInsets.zero,
                    borderRadius: BorderRadius.circular(16),
                    items: const [
                      DropdownMenuItem(
                        value: _Period.today,
                        child: Text('วันนี้'),
                      ),
                      DropdownMenuItem(
                        value: _Period.week,
                        child: Text('สัปดาห์นี้'),
                      ),
                      DropdownMenuItem(
                        value: _Period.month,
                        child: Text('เดือนนี้'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _period = value);
                    },
                  ),
                ],
              ),
              SizedBox(height: compact ? 8 : 12),
              Row(
                children: [
                  Expanded(
                    child: _SummaryCard(
                      label: 'รายรับ',
                      amount: income,
                      icon: Icons.south_west_rounded,
                      color: _incomeColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SummaryCard(
                      label: 'รายจ่าย',
                      amount: expenses,
                      icon: Icons.north_east_rounded,
                      color: _expenseColor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: compact ? 14 : 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'รายการล่าสุด',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: compact
                          ? VisualDensity.compact
                          : VisualDensity.standard,
                    ),
                    onPressed: () {
                      final shell = context
                          .findAncestorStateOfType<_WalletShellState>();
                      shell?.setState(() => shell._selectedIndex = 1);
                    },
                    child: const Text('ดูทั้งหมด'),
                  ),
                ],
              ),
              SizedBox(height: compact ? 2 : 4),
              if (widget.controller.transactions.isEmpty)
                _EmptyState(onAdd: widget.onAdd)
              else
                ...widget.controller.transactions
                    .take(5)
                    .map(
                      (transaction) => _TransactionTile(
                        transaction: transaction,
                        onTap: () =>
                            _showTransactionDetails(context, transaction),
                      ),
                    ),
              const SizedBox(height: 14),
              const _PrivacyNote(),
            ],
          ),
        );
      },
    );
  }
}

enum _Period { today, week, month }

class _GreetingHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Row(
      children: [
        Container(
          width: _isCompactLayout(context) ? 42 : 48,
          height: _isCompactLayout(context) ? 42 : 48,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.account_balance_wallet_rounded,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        SizedBox(width: _isCompactLayout(context) ? 9 : 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smart Wallet',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(
              DateFormat(
                _isCompactLayout(context)
                    ? 'd MMM yyyy'
                    : 'EEEEที่ d MMMM yyyy',
                'th_TH',
              ).format(now),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
        const Spacer(),
        IconButton(
          tooltip: 'รีเฟรชข้อมูล',
          onPressed: () => context
              .findAncestorStateOfType<_DashboardScreenState>()
              ?.widget
              .controller
              .load(),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.income,
    required this.expenses,
    required this.compact,
    required this.periodLabel,
  });

  final double income;
  final double expenses;
  final bool compact;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.all(compact ? 17 : 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF087F70), Color(0xFF07584F)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF087F70).withValues(alpha: .2),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'เงินสุทธิ$periodLabel',
            style: TextStyle(
              color: colorScheme.onPrimary.withValues(alpha: .8),
            ),
          ),
          SizedBox(height: compact ? 4 : 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _currencyFormat.format(income - expenses),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: compact ? 26 : null,
              ),
            ),
          ),
          SizedBox(height: compact ? 14 : 22),
          Row(
            children: [
              _BalanceMetric(label: 'รายรับ', amount: income),
              SizedBox(width: compact ? 20 : 28),
              _BalanceMetric(label: 'รายจ่าย', amount: expenses),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceMetric extends StatelessWidget {
  const _BalanceMetric({required this.label, required this.amount});

  final String label;
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70)),
        const SizedBox(height: 3),
        Text(
          _currencyFormat.format(amount),
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final double amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(_isCompactLayout(context) ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 19),
                const SizedBox(width: 7),
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            SizedBox(height: _isCompactLayout(context) ? 8 : 12),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _currencyFormat.format(amount),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(_isCompactLayout(context) ? 18 : 24),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 42,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(height: _isCompactLayout(context) ? 7 : 10),
            Text(
              'ยังไม่มีรายการ',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            const Text('เริ่มบันทึกรายรับหรือรายจ่ายรายการแรกของคุณ'),
            SizedBox(height: _isCompactLayout(context) ? 8 : 12),
            OutlinedButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('เพิ่มรายการแรก'),
            ),
          ],
        ),
      ),
    );
  }
}

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    required this.controller,
    required this.onEdit,
    super.key,
  });

  final WalletController controller;
  final ValueChanged<WalletTransaction> onEdit;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  TransactionType? _typeFilter;
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _delete(WalletTransaction transaction) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ลบรายการนี้?'),
        content: Text('ต้องการลบ “${transaction.title}” ใช่หรือไม่'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ลบรายการ'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.controller.delete(transaction);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ลบรายการเรียบร้อยแล้ว')));
      }
    } catch (error) {
      if (mounted) _showError(context, 'ลบรายการไม่สำเร็จ: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) {
        final transactions = widget.controller.transactions.where((item) {
          final matchesType = _typeFilter == null || item.type == _typeFilter;
          final query = _search.trim().toLowerCase();
          final matchesSearch =
              query.isEmpty ||
              item.title.toLowerCase().contains(query) ||
              item.category.toLowerCase().contains(query) ||
              item.note.toLowerCase().contains(query);
          return matchesType && matchesSearch;
        }).toList();
        final compact = _isCompactLayout(context);
        return Column(
          children: [
            _PageHeader(
              title: 'ประวัติรายการ',
              subtitle: 'จัดการและค้นหารายการทั้งหมดของคุณ',
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                compact ? 16 : 20,
                compact ? 6 : 10,
                compact ? 16 : 20,
                4,
              ),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'ค้นหารายการหรือหมวดหมู่',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _search.isEmpty
                      ? null
                      : IconButton(
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _search = '');
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                ),
                onChanged: (value) => setState(() => _search = value),
              ),
            ),
            SizedBox(
              height: compact ? 46 : 52,
              child: ListView(
                padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
                scrollDirection: Axis.horizontal,
                children: [
                  _FilterChip(
                    label: 'ทั้งหมด',
                    selected: _typeFilter == null,
                    onSelected: () => setState(() => _typeFilter = null),
                  ),
                  _FilterChip(
                    label: 'รายรับ',
                    selected: _typeFilter == TransactionType.income,
                    onSelected: () =>
                        setState(() => _typeFilter = TransactionType.income),
                  ),
                  _FilterChip(
                    label: 'รายจ่าย',
                    selected: _typeFilter == TransactionType.expense,
                    onSelected: () =>
                        setState(() => _typeFilter = TransactionType.expense),
                  ),
                ],
              ),
            ),
            Expanded(
              child: widget.controller.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : widget.controller.loadError != null
                  ? _LoadError(
                      error: widget.controller.loadError!,
                      onRetry: widget.controller.load,
                    )
                  : transactions.isEmpty
                  ? const Center(child: Text('ไม่พบรายการที่ตรงกับการค้นหา'))
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        compact ? 12 : 16,
                        4,
                        compact ? 12 : 16,
                        compact ? 76 : 100,
                      ),
                      itemCount: transactions.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 2),
                      itemBuilder: (context, index) {
                        final transaction = transactions[index];
                        return Dismissible(
                          key: ValueKey(transaction.id),
                          direction: DismissDirection.endToStart,
                          confirmDismiss: (_) async {
                            await _delete(transaction);
                            return false;
                          },
                          background: Container(
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.only(right: 24),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).colorScheme.errorContainer,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(Icons.delete_outline_rounded),
                          ),
                          child: _TransactionTile(
                            transaction: transaction,
                            onTap: () =>
                                _showTransactionDetails(context, transaction),
                            onEdit: () => widget.onEdit(transaction),
                            onDelete: () => _delete(transaction),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
    child: ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    ),
  );
}

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({required this.controller, super.key});

  final WalletController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final expenses = controller.transactions.where((item) {
          final now = DateTime.now();
          return !item.isIncome &&
              item.date.year == now.year &&
              item.date.month == now.month;
        });
        final byCategory = <String, double>{};
        for (final item in expenses) {
          byCategory.update(
            item.category,
            (value) => value + item.amount,
            ifAbsent: () => item.amount,
          );
        }
        final sortedEntries = byCategory.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        final total = byCategory.values.fold<double>(0, (a, b) => a + b);
        final compact = _isCompactLayout(context);
        return ListView(
          padding: EdgeInsets.fromLTRB(
            compact ? 16 : 20,
            compact ? 10 : 16,
            compact ? 16 : 20,
            compact ? 76 : 104,
          ),
          children: [
            _PageHeader(
              title: 'วิเคราะห์การเงิน',
              subtitle: 'ภาพรวมค่าใช้จ่ายประจำเดือนนี้',
            ),
            Card(
              child: Padding(
                padding: EdgeInsets.all(compact ? 16 : 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'รายจ่ายแยกตามหมวดหมู่',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text('รวม ${_currencyFormat.format(total)}'),
                    if (sortedEntries.isEmpty)
                      const SizedBox(
                        height: 220,
                        child: Center(
                          child: Text('ยังไม่มีข้อมูลรายจ่ายเดือนนี้'),
                        ),
                      )
                    else ...[
                      SizedBox(
                        height: compact ? 190 : 230,
                        child: PieChart(
                          PieChartData(
                            sectionsSpace: compact ? 2 : 3,
                            centerSpaceRadius: compact ? 40 : 48,
                            sections: [
                              for (var i = 0; i < sortedEntries.length; i++)
                                PieChartSectionData(
                                  value: sortedEntries[i].value,
                                  color:
                                      _categoryColors[i %
                                          _categoryColors.length],
                                  radius: compact ? 52 : 62,
                                  title: total == 0
                                      ? ''
                                      : '${(sortedEntries[i].value / total * 100).round()}%',
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      ...[
                        for (var i = 0; i < sortedEntries.length; i++)
                          _CategoryRow(
                            color: _categoryColors[i % _categoryColors.length],
                            name: sortedEntries[i].key,
                            amount: sortedEntries[i].value,
                            fraction: total == 0
                                ? 0
                                : sortedEntries[i].value / total,
                          ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'เคล็ดลับ: บันทึกรายการอย่างสม่ำเสมอเพื่อให้เห็นรูปแบบการใช้จ่ายที่ชัดเจน',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.color,
    required this.name,
    required this.amount,
    required this.fraction,
  });

  final Color color;
  final String name;
  final double amount;
  final double fraction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Expanded(child: Text(name)),
          Text(
            '${(fraction * 100).round()}%',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(width: 12),
          Text(
            _currencyFormat.format(amount),
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    required this.isDark,
    required this.onThemeChanged,
    super.key,
  });

  final bool isDark;
  final ValueChanged<bool> onThemeChanged;

  @override
  Widget build(BuildContext context) {
    final compact = _isCompactLayout(context);
    return ListView(
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 20,
        compact ? 10 : 16,
        compact ? 16 : 20,
        24,
      ),
      children: [
        _PageHeader(title: 'ตั้งค่า', subtitle: 'ปรับแอปให้เหมาะกับคุณ'),
        Card(
          child: SwitchListTile(
            dense: compact,
            secondary: const Icon(Icons.dark_mode_outlined),
            title: const Text('โหมดมืด'),
            subtitle: const Text('เปลี่ยนธีมการแสดงผลของแอป'),
            value: isDark,
            onChanged: onThemeChanged,
          ),
        ),
        SizedBox(height: compact ? 12 : 18),
        Center(
          child: Text(
            'Smart Wallet · เวอร์ชัน 1.0.0',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class TransactionEditor extends StatefulWidget {
  const TransactionEditor({
    required this.controller,
    this.transaction,
    super.key,
  });

  final WalletController controller;
  final WalletTransaction? transaction;

  @override
  State<TransactionEditor> createState() => _TransactionEditorState();
}

class _TransactionEditorState extends State<TransactionEditor> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();
  late TransactionType _type;
  late String _category;
  late DateTime _date;
  XFile? _newSlip;
  Uint8List? _newSlipBytes;
  bool _saving = false;

  bool get _editing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final item = widget.transaction;
    _titleController.text = item?.title ?? '';
    _amountController.text = item == null ? '' : item.amount.toStringAsFixed(2);
    _noteController.text = item?.note ?? '';
    _type = item?.type ?? TransactionType.expense;
    _category = item?.category ?? 'อาหาร';
    _date = item?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickSlip(ImageSource source) async {
    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 82,
        maxWidth: 1800,
      );
      if (image != null) {
        final bytes = kIsWeb ? await image.readAsBytes() : null;
        if (mounted) {
          setState(() {
            _newSlip = image;
            _newSlipBytes = bytes;
          });
        }
      }
    } catch (error) {
      if (mounted) _showError(context, 'เลือกรูปไม่สำเร็จ: $error');
    }
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
      locale: const Locale('th', 'TH'),
    );
    if (date != null) setState(() => _date = date);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final transaction = WalletTransaction(
      id: widget.transaction?.id,
      title: _titleController.text.trim(),
      amount: double.parse(_amountController.text.replaceAll(',', '').trim()),
      type: _type,
      category: _category,
      date: _date,
      note: _noteController.text.trim(),
      slipImagePath: widget.transaction?.slipImagePath,
    );
    try {
      await widget.controller.save(transaction, newSlip: _newSlip);
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(() => _saving = false);
        _showError(context, 'บันทึกไม่สำเร็จ: $error');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.transaction;
    final existingSlip = item?.slipImagePath;
    final slipPath = _newSlip?.path ?? existingSlip;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        _isCompactLayout(context) ? 16 : 20,
        12,
        _isCompactLayout(context) ? 16 : 20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              SizedBox(height: _isCompactLayout(context) ? 12 : 18),
              Text(
                _editing ? 'แก้ไขรายการ' : 'เพิ่มรายการใหม่',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: _isCompactLayout(context) ? 12 : 18),
              SegmentedButton<TransactionType>(
                segments: const [
                  ButtonSegment(
                    value: TransactionType.expense,
                    label: Text('รายจ่าย'),
                    icon: Icon(Icons.north_east_rounded),
                  ),
                  ButtonSegment(
                    value: TransactionType.income,
                    label: Text('รายรับ'),
                    icon: Icon(Icons.south_west_rounded),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (selection) =>
                    setState(() => _type = selection.first),
              ),
              SizedBox(height: _isCompactLayout(context) ? 10 : 14),
              TextFormField(
                controller: _titleController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'ชื่อรายการ',
                  hintText: 'เช่น ข้าวกลางวัน, เงินเดือน',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'กรุณากรอกชื่อรายการ'
                    : null,
              ),
              SizedBox(height: _isCompactLayout(context) ? 9 : 12),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'จำนวนเงิน',
                  prefixText: '฿ ',
                  hintText: '0.00',
                ),
                validator: (value) {
                  final amount = double.tryParse(
                    (value ?? '').replaceAll(',', '').trim(),
                  );
                  if (amount == null || !amount.isFinite || amount <= 0) {
                    return 'กรุณากรอกจำนวนเงินที่มากกว่า 0';
                  }
                  return null;
                },
              ),
              SizedBox(height: _isCompactLayout(context) ? 9 : 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(
                  labelText: 'หมวดหมู่',
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: transactionCategories
                    .map(
                      (category) => DropdownMenuItem(
                        value: category,
                        child: Text(category),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _category = value);
                },
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _chooseDate,
                icon: const Icon(Icons.calendar_month_rounded),
                label: Text('วันที่: ${_dateFormat.format(_date)}'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'บันทึกช่วยจำ (ไม่บังคับ)',
                  alignLabelWithHint: true,
                  prefixIcon: Icon(Icons.notes_rounded),
                ),
              ),
              SizedBox(height: _isCompactLayout(context) ? 10 : 14),
              Text(
                'สลิปหรือใบเสร็จ (ไม่บังคับ)',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              if (slipPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: _isCompactLayout(context) ? 112 : 150,
                    child: _SlipPreview(
                      path: slipPath,
                      isTemporary: _newSlip != null,
                      bytes: _newSlipBytes,
                    ),
                  ),
                ),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickSlip(ImageSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('แกลเลอรี'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickSlip(ImageSource.camera),
                      icon: const Icon(Icons.camera_alt_outlined),
                      label: const Text('ถ่ายรูป'),
                    ),
                  ),
                ],
              ),
              SizedBox(height: _isCompactLayout(context) ? 9 : 12),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Padding(
                  padding: const EdgeInsets.all(13),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(_editing ? 'บันทึกการแก้ไข' : 'บันทึกรายการ'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlipPreview extends StatelessWidget {
  const _SlipPreview({
    required this.path,
    required this.isTemporary,
    this.bytes,
  });

  final String path;
  final bool isTemporary;
  final Uint8List? bytes;

  @override
  Widget build(BuildContext context) {
    if (isTemporary) {
      if (kIsWeb) {
        if (bytes == null) return const SizedBox.shrink();
        return Image.memory(bytes!, fit: BoxFit.cover);
      }
      return Image.file(File(path), fit: BoxFit.cover);
    }
    return _SlipImage(path: path);
  }
}

class _SlipImage extends StatelessWidget {
  const _SlipImage({required this.path});

  final String path;

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      const base64Marker = 'base64,';
      final markerIndex = path.indexOf(base64Marker);
      if (markerIndex < 0) return _missingSlipImage(context);
      return Image.memory(
        base64Decode(path.substring(markerIndex + base64Marker.length)),
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _missingSlipImage(context),
      );
    }
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      errorBuilder: (_, _, _) => _missingSlipImage(context),
    );
  }
}

Widget _missingSlipImage(BuildContext context) => Container(
  color: Theme.of(context).colorScheme.surfaceContainerHighest,
  alignment: Alignment.center,
  child: const Text('ไม่พบไฟล์รูปสลิป'),
);

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.onTap,
    this.onEdit,
    this.onDelete,
  });

  final WalletTransaction transaction;
  final VoidCallback onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final color = transaction.isIncome ? _incomeColor : _expenseColor;
    final compact = _isCompactLayout(context);
    return Card(
      margin: EdgeInsets.symmetric(vertical: compact ? 2 : 4),
      child: ListTile(
        dense: compact,
        contentPadding: EdgeInsets.symmetric(horizontal: compact ? 12 : 16),
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          child: Icon(_categoryIcon(transaction.category), color: color),
        ),
        title: Text(
          transaction.title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${transaction.category} · ${_dateFormat.format(transaction.date)}'
          '${transaction.slipImagePath == null ? '' : ' · มีสลิป'}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${transaction.isIncome ? '+' : '−'}${_currencyFormat.format(transaction.amount)}',
              style: TextStyle(color: color, fontWeight: FontWeight.w800),
            ),
            if (onEdit != null || onDelete != null)
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit?.call();
                  if (value == 'delete') onDelete?.call();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'edit', child: Text('แก้ไข')),
                  PopupMenuItem(value: 'delete', child: Text('ลบ')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

IconData _categoryIcon(String category) {
  return switch (category) {
    'อาหาร' => Icons.restaurant_rounded,
    'เดินทาง' => Icons.directions_car_rounded,
    'ช้อปปิ้ง' => Icons.shopping_bag_rounded,
    'บิล/ค่าน้ำไฟ' => Icons.receipt_rounded,
    'สุขภาพ' => Icons.favorite_rounded,
    'การศึกษา' => Icons.menu_book_rounded,
    'เงินเดือน' => Icons.account_balance_rounded,
    'เงินพิเศษ' => Icons.card_giftcard_rounded,
    _ => Icons.wallet_rounded,
  };
}

Future<void> _showTransactionDetails(
  BuildContext context,
  WalletTransaction transaction,
) {
  final color = transaction.isIncome ? _incomeColor : _expenseColor;
  return showDialog<void>(
    context: context,
    builder: (context) => Dialog(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(_categoryIcon(transaction.category), color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    transaction.title,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text(
              '${transaction.isIncome ? '+' : '−'}${_currencyFormat.format(transaction.amount)}',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${transaction.category} · ${_dateFormat.format(transaction.date)}',
            ),
            if (transaction.note.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(transaction.note),
            ],
            if (transaction.slipImagePath != null) ...[
              const SizedBox(height: 16),
              Text(
                'สลิป/ใบเสร็จ',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: _SlipImage(path: transaction.slipImagePath!),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 2, 4, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
      ],
    ),
  );
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Icon(
        Icons.lock_outline_rounded,
        size: 14,
        color: Theme.of(context).colorScheme.outline,
      ),
      const SizedBox(width: 5),
      Text(
        'ข้อมูลและสลิปเก็บไว้ในอุปกรณ์ของคุณ',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    ],
  );
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.error, required this.onRetry});

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, size: 42),
          const SizedBox(height: 8),
          const Text('โหลดข้อมูลไม่สำเร็จ'),
          const SizedBox(height: 4),
          Text(
            '$error',
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('ลองอีกครั้ง'),
          ),
        ],
      ),
    ),
  );
}

void _showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
  );
}
