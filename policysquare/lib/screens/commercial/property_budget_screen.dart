import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:policysquare/data/models/property_budget.dart';
import 'package:policysquare/providers/commercial_provider.dart';
import 'package:policysquare/screens/commercial/property_budget_history_screen.dart';

class PropertyBudgetScreen extends StatefulWidget {
  const PropertyBudgetScreen({super.key});

  @override
  State<PropertyBudgetScreen> createState() => _PropertyBudgetScreenState();
}

class _PropertyBudgetScreenState extends State<PropertyBudgetScreen> {
  final _addressController = TextEditingController();
  final List<BudgetLineItem> _lineItems = [];

  static const List<String> _categories = [
    'Roof & Structure',
    'Electrical',
    'Plumbing',
    'Fire Safety',
    'HVAC',
    'Painting & Finishing',
    'Landscaping',
    'Other',
  ];

  static const List<String> _priorities = ['Low', 'Medium', 'High'];

  @override
  void dispose() {
    _addressController.dispose();
    super.dispose();
  }

  double get _totalEstimatedCost =>
      _lineItems.fold(0.0, (sum, item) => sum + item.estimatedCost);

  Future<void> _showAddLineItemDialog() async {
    final descriptionController = TextEditingController();
    final costController = TextEditingController();
    String category = _categories.first;
    String priority = _priorities[1];

    final added = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Budget Item'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: _categories
                          .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => category = val ?? category),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        hintText: 'e.g. Replace damaged roof shingles',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: costController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Estimated Cost',
                        prefixText: '\$ ',
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: _priorities
                          .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                          .toList(),
                      onChanged: (val) =>
                          setDialogState(() => priority = val ?? priority),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final cost = double.tryParse(costController.text.trim());
                    if (descriptionController.text.trim().isEmpty ||
                        cost == null ||
                        cost < 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Please enter a description and a valid cost.',
                          ),
                        ),
                      );
                      return;
                    }
                    _lineItems.add(
                      BudgetLineItem(
                        category: category,
                        description: descriptionController.text.trim(),
                        estimatedCost: cost,
                        priority: priority,
                      ),
                    );
                    Navigator.pop(context, true);
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );

    if (added == true && mounted) {
      setState(() {});
    }
  }

  Color _priorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Low':
        return Colors.green;
      default:
        return Colors.orange;
    }
  }

  Future<void> _saveBudget() async {
    if (_lineItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one budget item first.')),
      );
      return;
    }

    final budget = PropertyBudget(
      propertyAddress: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      status: 'DRAFT',
      totalEstimatedCost: _totalEstimatedCost,
      data: jsonEncode(_lineItems.map((e) => e.toJson()).toList()),
    );

    final provider = context.read<CommercialProvider>();
    final result = await provider.submitPropertyBudget(budget);

    if (!mounted) return;

    if (result != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Property budget ${result.id} saved.')),
      );
      setState(() {
        _lineItems.clear();
        _addressController.clear();
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to save budget: ${provider.error ?? 'Unknown error'}',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Budget'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'View Saved Budgets',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const PropertyBudgetHistoryScreen(),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Repair & Maintenance Budget',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Itemize expected repair or maintenance costs for the property and track the total budget.',
                  style: TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _addressController,
                  decoration: const InputDecoration(
                    labelText: 'Property Address (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Budget Items',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    TextButton.icon(
                      onPressed: _showAddLineItemDialog,
                      icon: const Icon(Icons.add),
                      label: const Text('Add Item'),
                    ),
                  ],
                ),
                if (_lineItems.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: Text(
                        'No items added yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  )
                else
                  ...List.generate(_lineItems.length, (index) {
                    final item = _lineItems[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(item.description),
                        subtitle: Text(item.category),
                        leading: CircleAvatar(
                          backgroundColor:
                              _priorityColor(item.priority).withOpacity(0.15),
                          child: Icon(
                            Icons.priority_high,
                            color: _priorityColor(item.priority),
                            size: 18,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '\$${item.estimatedCost.toStringAsFixed(2)}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20),
                              onPressed: () =>
                                  setState(() => _lineItems.removeAt(index)),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: Consumer<CommercialProvider>(
              builder: (context, provider, _) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Total Estimated Budget',
                        style: TextStyle(fontSize: 14, color: Colors.grey),
                      ),
                      Text(
                        '\$${_totalEstimatedCost.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1565C0),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: provider.isLoading ? null : _saveBudget,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1565C0),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: provider.isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('SAVE BUDGET'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
