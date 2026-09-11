import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:policysquare/data/models/property_budget.dart';
import 'package:policysquare/providers/commercial_provider.dart';

class PropertyBudgetHistoryScreen extends StatefulWidget {
  const PropertyBudgetHistoryScreen({super.key});

  @override
  State<PropertyBudgetHistoryScreen> createState() =>
      _PropertyBudgetHistoryScreenState();
}

class _PropertyBudgetHistoryScreenState
    extends State<PropertyBudgetHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CommercialProvider>().loadMobileNumber();
    });
  }

  String _formatDate(dynamic rawDate) {
    if (rawDate == null) return 'N/A';
    try {
      if (rawDate is List && rawDate.length >= 3) {
        final date = DateTime(rawDate[0] as int, rawDate[1] as int, rawDate[2] as int);
        return DateFormat('dd-MMM-yy').format(date).toUpperCase();
      }
      final date = DateTime.tryParse(rawDate.toString());
      if (date != null) return DateFormat('dd-MMM-yy').format(date).toUpperCase();
      return rawDate.toString();
    } catch (e) {
      return rawDate.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Property Budgets'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: Consumer<CommercialProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.budgetHistory.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.account_balance_wallet_outlined,
                      size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'No property budgets saved yet.',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.budgetHistory.length,
            itemBuilder: (context, index) {
              final budget = provider.budgetHistory[index];
              return _buildBudgetCard(budget);
            },
          );
        },
      ),
    );
  }

  Widget _buildBudgetCard(PropertyBudget budget) {
    List<dynamic> items = [];
    try {
      items = jsonDecode(budget.data ?? '[]') as List<dynamic>;
    } catch (_) {
      items = [];
    }

    return Card(
      elevation: 3,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: ExpansionTile(
        title: Text(
          budget.propertyAddress ?? 'Budget ${budget.id ?? ''}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          '${_formatDate(budget.createdAt)} · ${items.length} item(s) · ${budget.status ?? 'DRAFT'}',
        ),
        trailing: Text(
          '\$${(budget.totalEstimatedCost ?? 0).toStringAsFixed(2)}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0),
          ),
        ),
        children: items.map((rawItem) {
          final item = rawItem as Map<String, dynamic>;
          return ListTile(
            dense: true,
            title: Text(item['description']?.toString() ?? ''),
            subtitle: Text(
              '${item['category'] ?? ''} · ${item['priority'] ?? ''}',
            ),
            trailing: Text(
              '\$${(item['estimatedCost'] as num? ?? 0).toStringAsFixed(2)}',
            ),
          );
        }).toList(),
      ),
    );
  }
}
