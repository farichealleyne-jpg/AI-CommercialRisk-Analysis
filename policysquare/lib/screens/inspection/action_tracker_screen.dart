import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:policysquare/config/inspection_guide.dart';
import 'package:policysquare/data/models/action_item.dart';
import 'package:policysquare/providers/inspection_provider.dart';
import 'package:policysquare/screens/inspection/action_detail_screen.dart';

/// Deficiency tracker: every unresolved issue, from discovery through quote,
/// approval, completion and verification.
class ActionTrackerScreen extends StatefulWidget {
  /// When set, the list is scoped to one visit and new items attach to it.
  final String? visitId;
  final String? propertyCode;

  const ActionTrackerScreen({super.key, this.visitId, this.propertyCode});

  @override
  State<ActionTrackerScreen> createState() => _ActionTrackerScreenState();
}

class _ActionTrackerScreenState extends State<ActionTrackerScreen> {
  bool _openOnly = true;

  static final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  static Color priorityColor(String? priority) => switch (priority) {
        'CRITICAL' => const Color(0xFFC62828),
        'HIGH' => const Color(0xFFEF6C00),
        'LOW' => const Color(0xFF2E7D32),
        _ => const Color(0xFFF9A825),
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.visitId != null ? 'Actions · ${widget.visitId}' : 'Action Tracker',
        ),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: _openOnly ? 'Showing open only' : 'Showing all',
            icon: Icon(_openOnly ? Icons.filter_alt : Icons.filter_alt_off),
            onPressed: () => setState(() => _openOnly = !_openOnly),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAction(context),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add action'),
      ),
      body: Consumer<InspectionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.actions.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          var items = provider.actions;
          if (widget.visitId != null) {
            items = items.where((a) => a.visitId == widget.visitId).toList();
          }
          if (_openOnly) {
            items = items.where((a) => a.status != 'CLOSED').toList();
          }

          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.checklist, size: 64, color: Colors.grey),
                    const SizedBox(height: 16),
                    Text(
                      _openOnly ? 'No open actions' : 'No actions recorded',
                      style: const TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: items.length,
            itemBuilder: (context, index) => _actionCard(context, items[index]),
          );
        },
      ),
    );
  }

  Widget _actionCard(BuildContext context, ActionItem action) {
    final color = priorityColor(action.priority);
    final isOverdue = action.overdue == true;
    final needsCapital = action.requiresCapitalReview == true;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openAction(context, existing: action),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          action.issue ?? 'Untitled issue',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${action.id} · ${action.category ?? "Uncategorised"}'
                          '${action.location?.isNotEmpty == true ? " · ${action.location}" : ""}',
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  if (action.estimatedCost != null)
                    Text(
                      _currency.format(action.estimatedCost),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _chip(
                    (action.priority ?? 'MEDIUM').toLowerCase(),
                    color,
                  ),
                  _chip(
                    InspectionGuide.statusLabel(action.status),
                    const Color(0xFF1565C0),
                  ),
                  if (action.safetyHazard == true)
                    _chip('safety hazard', const Color(0xFFC62828),
                        icon: Icons.warning_amber_rounded),
                  if (needsCapital)
                    _chip('capital review', const Color(0xFF6A1B9A),
                        icon: Icons.account_balance),
                  if (isOverdue)
                    _chip('overdue', const Color(0xFFEF6C00),
                        icon: Icons.schedule),
                  if (action.leaseReview == true)
                    _chip('lease review', Colors.teal),
                  if (action.approvalStatus == 'PENDING')
                    _chip('approval pending', const Color(0xFF6A1B9A),
                        icon: Icons.how_to_reg),
                  if (action.approvalStatus == 'APPROVED')
                    _chip('approved', const Color(0xFF2E7D32),
                        icon: Icons.check_circle_outline),
                  if (action.approvalStatus == 'DECLINED')
                    _chip('declined', const Color(0xFFC62828),
                        icon: Icons.block),
                ],
              ),
              if (_meta(action).isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  _meta(action).join('  ·  '),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Whichever of responsibility, dates and sign-off the item has reached.
  List<String> _meta(ActionItem action) => [
        if (action.responsibleParty?.isNotEmpty == true)
          'Responsible: ${action.responsibleParty}',
        if (action.targetCompletion != null)
          'Target: ${_formatDate(action.targetCompletion)}',
        if (action.completionDate != null)
          'Completed: ${_formatDate(action.completionDate)}',
        if (action.verifiedBy?.isNotEmpty == true)
          'Verified by ${action.verifiedBy}',
        if (action.vendorRef?.isNotEmpty == true) action.vendorRef!,
      ];

  Future<void> _openAction(BuildContext context, {ActionItem? existing}) {
    return Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActionDetailScreen(
          existing: existing,
          visitId: widget.visitId,
          propertyCode: widget.propertyCode,
        ),
      ),
    );
  }

  static String _formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final parsed = DateTime.tryParse(iso);
    return parsed == null ? iso : DateFormat('dd MMM yyyy').format(parsed);
  }

  Widget _chip(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

}
