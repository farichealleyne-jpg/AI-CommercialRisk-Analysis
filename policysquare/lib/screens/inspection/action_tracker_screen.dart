import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:policysquare/config/inspection_guide.dart';
import 'package:policysquare/data/models/action_item.dart';
import 'package:policysquare/providers/inspection_provider.dart';

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
  static final _isoDate = DateFormat('yyyy-MM-dd');

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
        onPressed: () => _showActionDialog(context),
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
        onTap: () => _showActionDialog(context, existing: action),
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
                ],
              ),
              if (action.responsibleParty?.isNotEmpty == true ||
                  action.targetCompletion != null) ...[
                const SizedBox(height: 8),
                Text(
                  [
                    if (action.responsibleParty?.isNotEmpty == true)
                      'Responsible: ${action.responsibleParty}',
                    if (action.targetCompletion != null)
                      'Target: ${_formatDate(action.targetCompletion)}',
                  ].join('  ·  '),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ],
          ),
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

  Future<void> _showActionDialog(
    BuildContext context, {
    ActionItem? existing,
  }) async {
    final provider = context.read<InspectionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final isEdit = existing != null;

    String? propertyCode = existing?.propertyCode ??
        widget.propertyCode ??
        (provider.properties.isNotEmpty ? provider.properties.first.code : null);
    String? visitId = existing?.visitId ?? widget.visitId;
    String category = InspectionGuide.categories.contains(existing?.category)
        ? existing!.category!
        : InspectionGuide.categories.first;
    String priority = existing?.priority ?? 'MEDIUM';
    String status = existing?.status ?? 'OPEN';
    String responsible = InspectionGuide.responsibleParties
            .contains(existing?.responsibleParty)
        ? existing!.responsibleParty!
        : InspectionGuide.responsibleParties.first;
    bool safetyHazard = existing?.safetyHazard ?? false;
    bool leaseReview = existing?.leaseReview ?? false;
    DateTime? targetDate = existing?.targetCompletion == null
        ? null
        : DateTime.tryParse(existing!.targetCompletion!);

    final locationController =
        TextEditingController(text: existing?.location ?? '');
    final issueController = TextEditingController(text: existing?.issue ?? '');
    final costController = TextEditingController(
      text: existing?.estimatedCost?.toStringAsFixed(0) ?? '',
    );
    final ownerController =
        TextEditingController(text: existing?.actionOwner ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final cost = double.tryParse(costController.text.trim());
          final overThreshold =
              cost != null && cost > InspectionGuide.capitalReviewThreshold;

          return AlertDialog(
            title: Text(isEdit ? 'Edit action' : 'Add action'),
            content: SizedBox(
              width: 400,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isEdit && widget.visitId == null) ...[
                      DropdownButtonFormField<String>(
                        initialValue: propertyCode,
                        decoration:
                            const InputDecoration(labelText: 'Property'),
                        items: provider.properties
                            .map((p) => DropdownMenuItem(
                                  value: p.code,
                                  child: Text('${p.code} · ${p.name}'),
                                ))
                            .toList(),
                        onChanged: (value) => setDialogState(() {
                          propertyCode = value;
                          visitId = null;
                        }),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String?>(
                        initialValue: visitId,
                        decoration: const InputDecoration(
                          labelText: 'Visit (optional)',
                        ),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Not linked to a visit'),
                          ),
                          ...provider.visits
                              .where((v) => v.propertyCode == propertyCode)
                              .map((v) => DropdownMenuItem<String?>(
                                    value: v.id,
                                    child: Text(v.id ?? ''),
                                  )),
                        ],
                        onChanged: (value) =>
                            setDialogState(() => visitId = value),
                      ),
                      const SizedBox(height: 10),
                    ],
                    DropdownButtonFormField<String>(
                      initialValue: category,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: InspectionGuide.categories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => category = value ?? category),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location',
                        hintText: 'e.g. North parking lot',
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: issueController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Issue / deficiency',
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: InspectionGuide.priorities
                          .map((p) => DropdownMenuItem(
                                value: p,
                                child: Text(InspectionGuide.statusLabel(p)),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => priority = value ?? priority),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: InspectionGuide.actionStatuses
                          .map((s) => DropdownMenuItem(
                                value: s,
                                child: Text(InspectionGuide.statusLabel(s)),
                              ))
                          .toList(),
                      onChanged: (value) =>
                          setDialogState(() => status = value ?? status),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: responsible,
                      decoration:
                          const InputDecoration(labelText: 'Responsible party'),
                      items: InspectionGuide.responsibleParties
                          .map((r) =>
                              DropdownMenuItem(value: r, child: Text(r)))
                          .toList(),
                      onChanged: (value) => setDialogState(
                          () => responsible = value ?? responsible),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: ownerController,
                      decoration:
                          const InputDecoration(labelText: 'Action owner'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: costController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Estimated cost',
                        prefixText: '\$ ',
                      ),
                      onChanged: (_) => setDialogState(() {}),
                    ),
                    if (overThreshold)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Row(
                          children: [
                            const Icon(Icons.account_balance,
                                size: 14, color: Color(0xFF6A1B9A)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Above the ${_currency.format(InspectionGuide.capitalReviewThreshold)} '
                                'threshold — requires the capital-work approval process.',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6A1B9A),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 10),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: targetDate ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setDialogState(() => targetDate = picked);
                        }
                      },
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Target completion',
                          suffixIcon: Icon(Icons.calendar_today, size: 18),
                        ),
                        child: Text(
                          targetDate == null
                              ? 'Not set'
                              : DateFormat('dd MMM yyyy').format(targetDate!),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: safetyHazard,
                      onChanged: (value) =>
                          setDialogState(() => safetyHazard = value ?? false),
                      title: const Text('Safety hazard',
                          style: TextStyle(fontSize: 14)),
                      subtitle: const Text(
                        'Surfaces separately on the dashboard',
                        style: TextStyle(fontSize: 11),
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: leaseReview,
                      onChanged: (value) =>
                          setDialogState(() => leaseReview = value ?? false),
                      title: const Text('Lease review required',
                          style: TextStyle(fontSize: 14)),
                      controlAffinity: ListTileControlAffinity.leading,
                      dense: true,
                    ),
                    const SizedBox(height: 4),
                    TextField(
                      controller: notesController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Notes'),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (issueController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(
                        content: Text('Describe the issue before saving.'),
                      ),
                    );
                    return;
                  }
                  if (propertyCode == null) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('Select a property.')),
                    );
                    return;
                  }
                  Navigator.pop(dialogContext, true);
                },
                child: Text(isEdit ? 'Save' : 'Add'),
              ),
            ],
          );
        },
      ),
    );

    if (saved != true) return;

    final cost = double.tryParse(costController.text.trim());
    final action = ActionItem(
      visitId: visitId,
      propertyCode: propertyCode,
      location: locationController.text.trim(),
      category: category,
      issue: issueController.text.trim(),
      priority: priority,
      safetyHazard: safetyHazard,
      leaseReview: leaseReview,
      responsibleParty: responsible,
      actionOwner: ownerController.text.trim(),
      status: status,
      targetCompletion:
          targetDate == null ? null : _isoDate.format(targetDate!),
      estimatedCost: cost,
      costClassification:
          cost != null && cost > InspectionGuide.capitalReviewThreshold
              ? 'CAPITAL'
              : 'OPERATING',
      notes: notesController.text.trim(),
    );

    final result = isEdit
        ? await provider.updateAction(existing.id!, action)
        : await provider.addAction(action);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result != null
              ? 'Action ${result.id} saved.'
              : 'Could not save: ${provider.error ?? "unknown error"}',
        ),
        backgroundColor: result != null ? null : Colors.red,
      ),
    );
  }
}
