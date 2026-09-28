import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:policysquare/config/inspection_guide.dart';
import 'package:policysquare/data/models/action_item.dart';
import 'package:policysquare/providers/inspection_provider.dart';

/// Full record for one deficiency. An action carries the whole workbook field
/// set, which is more than a dialog can hold, so it gets its own form grouped
/// by the stage of work each field belongs to.
class ActionDetailScreen extends StatefulWidget {
  final ActionItem? existing;

  /// Pre-selected context when raising an action from a specific visit.
  final String? visitId;
  final String? propertyCode;

  const ActionDetailScreen({
    super.key,
    this.existing,
    this.visitId,
    this.propertyCode,
  });

  @override
  State<ActionDetailScreen> createState() => _ActionDetailScreenState();
}

class _ActionDetailScreenState extends State<ActionDetailScreen> {
  static final _isoDate = DateFormat('yyyy-MM-dd');
  static final _currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

  String? _propertyCode;
  String? _visitId;
  late String _category;
  late String _priority;
  late String _status;
  late String _responsible;
  late String _approvalStatus;
  late String _costClassification;
  bool _safetyHazard = false;
  bool _leaseReview = false;
  DateTime? _targetCompletion;
  DateTime? _completionDate;

  final _locationController = TextEditingController();
  final _issueController = TextEditingController();
  final _immediateControlController = TextEditingController();
  final _tenantUnitController = TextEditingController();
  final _ownerController = TextEditingController();
  final _costController = TextEditingController();
  final _verifiedByController = TextEditingController();
  final _vendorController = TextEditingController();
  final _evidenceController = TextEditingController();
  final _notesController = TextEditingController();

  bool get _isEdit => widget.existing != null;

  double? get _cost => double.tryParse(_costController.text.trim());

  bool get _overThreshold =>
      _cost != null && _cost! > InspectionGuide.capitalReviewThreshold;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final provider = context.read<InspectionProvider>();

    _propertyCode = existing?.propertyCode ??
        widget.propertyCode ??
        (provider.properties.isNotEmpty ? provider.properties.first.code : null);
    _visitId = existing?.visitId ?? widget.visitId;
    _category = InspectionGuide.categories.contains(existing?.category)
        ? existing!.category!
        : InspectionGuide.categories.first;
    _priority = existing?.priority ?? 'MEDIUM';
    _status = existing?.status ?? 'OPEN';
    _responsible =
        InspectionGuide.responsibleParties.contains(existing?.responsibleParty)
            ? existing!.responsibleParty!
            : InspectionGuide.responsibleParties.first;
    _approvalStatus =
        InspectionGuide.approvalStatuses.contains(existing?.approvalStatus)
            ? existing!.approvalStatus!
            : 'NOT_REQUIRED';
    _costClassification = InspectionGuide.costClassifications
            .contains(existing?.costClassification)
        ? existing!.costClassification!
        : 'OPERATING';
    _safetyHazard = existing?.safetyHazard ?? false;
    _leaseReview = existing?.leaseReview ?? false;
    _targetCompletion = existing?.targetCompletion == null
        ? null
        : DateTime.tryParse(existing!.targetCompletion!);
    _completionDate = existing?.completionDate == null
        ? null
        : DateTime.tryParse(existing!.completionDate!);

    _locationController.text = existing?.location ?? '';
    _issueController.text = existing?.issue ?? '';
    _immediateControlController.text = existing?.immediateControl ?? '';
    _tenantUnitController.text = existing?.tenantUnit ?? '';
    _ownerController.text = existing?.actionOwner ?? '';
    _costController.text = existing?.estimatedCost?.toStringAsFixed(0) ?? '';
    _verifiedByController.text = existing?.verifiedBy ?? '';
    _vendorController.text = existing?.vendorRef ?? '';
    _evidenceController.text = existing?.evidenceLink ?? '';
    _notesController.text = existing?.notes ?? '';
  }

  @override
  void dispose() {
    _locationController.dispose();
    _issueController.dispose();
    _immediateControlController.dispose();
    _tenantUnitController.dispose();
    _ownerController.dispose();
    _costController.dispose();
    _verifiedByController.dispose();
    _vendorController.dispose();
    _evidenceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_issueController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Describe the issue before saving.')),
      );
      return;
    }
    if (_propertyCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a property.')),
      );
      return;
    }

    final provider = context.read<InspectionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final action = ActionItem(
      visitId: _visitId,
      propertyCode: _propertyCode,
      location: _locationController.text.trim(),
      category: _category,
      issue: _issueController.text.trim(),
      priority: _priority,
      safetyHazard: _safetyHazard,
      immediateControl: _immediateControlController.text.trim(),
      responsibleParty: _responsible,
      tenantUnit: _tenantUnitController.text.trim(),
      leaseReview: _leaseReview,
      actionOwner: _ownerController.text.trim(),
      status: _status,
      targetCompletion: _targetCompletion == null
          ? null
          : _isoDate.format(_targetCompletion!),
      completionDate:
          _completionDate == null ? null : _isoDate.format(_completionDate!),
      verifiedBy: _verifiedByController.text.trim(),
      estimatedCost: _cost,
      costClassification: _overThreshold ? 'CAPITAL' : _costClassification,
      approvalStatus: _approvalStatus,
      vendorRef: _vendorController.text.trim(),
      evidenceLink: _evidenceController.text.trim(),
      notes: _notesController.text.trim(),
    );

    final result = _isEdit
        ? await provider.updateAction(widget.existing!.id!, action)
        : await provider.addAction(action);

    if (result != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Action ${result.id} saved.')),
      );
      navigator.pop();
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not save: ${provider.error ?? "unknown error"}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<InspectionProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? widget.existing!.id ?? 'Action' : 'New Action'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _section('The issue'),
          if (widget.visitId == null) ...[
            DropdownButtonFormField<String>(
              initialValue: _propertyCode,
              decoration: _dec('Property'),
              items: provider.properties
                  .map((p) => DropdownMenuItem(
                        value: p.code,
                        child: Text('${p.code} · ${p.name}'),
                      ))
                  .toList(),
              onChanged: _isEdit
                  ? null
                  : (value) => setState(() {
                        _propertyCode = value;
                        _visitId = null;
                      }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _visitId,
              decoration: _dec('Raised on visit'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Not linked to a visit'),
                ),
                ...provider.visits
                    .where((v) => v.propertyCode == _propertyCode)
                    .map((v) => DropdownMenuItem<String?>(
                          value: v.id,
                          child: Text(v.id ?? ''),
                        )),
              ],
              onChanged:
                  _isEdit ? null : (value) => setState(() => _visitId = value),
            ),
            const SizedBox(height: 12),
          ],
          DropdownButtonFormField<String>(
            initialValue: _category,
            isExpanded: true,
            decoration: _dec('Category'),
            items: InspectionGuide.categories
                .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                .toList(),
            onChanged: (value) =>
                setState(() => _category = value ?? _category),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _locationController,
            decoration: _dec('Location', hint: 'e.g. North parking lot'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _issueController,
            maxLines: 3,
            decoration: _dec('Issue / deficiency'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _priority,
            decoration: _dec('Priority'),
            items: InspectionGuide.priorities
                .map((p) => DropdownMenuItem(
                      value: p,
                      child: Text(InspectionGuide.statusLabel(p)),
                    ))
                .toList(),
            onChanged: (value) =>
                setState(() => _priority = value ?? _priority),
          ),
          const SizedBox(height: 4),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _safetyHazard,
            onChanged: (value) =>
                setState(() => _safetyHazard = value ?? false),
            title: const Text('Safety hazard', style: TextStyle(fontSize: 14)),
            subtitle: const Text(
              'Counted separately on the dashboard',
              style: TextStyle(fontSize: 11),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
          if (_safetyHazard) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _immediateControlController,
              maxLines: 2,
              decoration: _dec(
                'Immediate control taken',
                hint: 'What was done on the day to make it safe',
              ),
            ),
          ],

          const SizedBox(height: 24),
          _section('Responsibility'),
          DropdownButtonFormField<String>(
            initialValue: _responsible,
            decoration: _dec('Responsible party'),
            items: InspectionGuide.responsibleParties
                .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                .toList(),
            onChanged: (value) =>
                setState(() => _responsible = value ?? _responsible),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ownerController,
            decoration: _dec('Action owner', hint: 'Person chasing this'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tenantUnitController,
            decoration: _dec('Tenant / unit', hint: 'If tenant-related'),
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _leaseReview,
            onChanged: (value) => setState(() => _leaseReview = value ?? false),
            title: const Text('Lease review required',
                style: TextStyle(fontSize: 14)),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),

          const SizedBox(height: 24),
          _section('Cost and approval'),
          TextField(
            controller: _costController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: _dec('Estimated cost').copyWith(prefixText: '\$ '),
            onChanged: (_) => setState(() {}),
          ),
          if (_overThreshold)
            Container(
              margin: const EdgeInsets.only(top: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF6A1B9A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance,
                      size: 16, color: Color(0xFF6A1B9A)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Above the ${_currency.format(InspectionGuide.capitalReviewThreshold)} '
                      'threshold — classified as capital work and routed for approval.',
                      style: const TextStyle(
                          fontSize: 11.5, color: Color(0xFF6A1B9A)),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _overThreshold ? 'CAPITAL' : _costClassification,
            decoration: _dec('Cost classification'),
            items: InspectionGuide.costClassifications
                .map((c) => DropdownMenuItem(
                      value: c,
                      child: Text(InspectionGuide.statusLabel(c)),
                    ))
                .toList(),
            // Above the threshold the classification is not the user's to pick.
            onChanged: _overThreshold
                ? null
                : (value) => setState(
                    () => _costClassification = value ?? _costClassification),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _approvalStatus,
            decoration: _dec('Approval status'),
            items: InspectionGuide.approvalStatuses
                .map((a) => DropdownMenuItem(
                      value: a,
                      child: Text(InspectionGuide.statusLabel(a)),
                    ))
                .toList(),
            onChanged: (value) =>
                setState(() => _approvalStatus = value ?? _approvalStatus),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _vendorController,
            decoration: _dec('Vendor / WO / PO'),
          ),

          const SizedBox(height: 24),
          _section('Progress and closure'),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: _dec('Status'),
            items: InspectionGuide.actionStatuses
                .map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(InspectionGuide.statusLabel(s)),
                    ))
                .toList(),
            onChanged: (value) => setState(() => _status = value ?? _status),
          ),
          const SizedBox(height: 12),
          _dateField(
            label: 'Target completion',
            value: _targetCompletion,
            onPick: (picked) => setState(() => _targetCompletion = picked),
            onClear: () => setState(() => _targetCompletion = null),
          ),
          const SizedBox(height: 12),
          _dateField(
            label: 'Completion date',
            value: _completionDate,
            onPick: (picked) => setState(() => _completionDate = picked),
            onClear: () => setState(() => _completionDate = null),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _verifiedByController,
            decoration: _dec(
              'Verified by',
              hint: 'Who confirmed the work was done',
            ),
          ),

          const SizedBox(height: 24),
          _section('Evidence'),
          TextField(
            controller: _evidenceController,
            decoration: _dec(
              'Evidence / record link',
              hint: 'Photos, report or file reference',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notesController,
            maxLines: 3,
            decoration: _dec('Notes'),
          ),

          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: provider.isLoading ? null : _save,
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
                  : Text(_isEdit ? 'SAVE CHANGES' : 'ADD ACTION'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1565C0),
          ),
        ),
      );

  InputDecoration _dec(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      );

  Widget _dateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onPick,
    required VoidCallback onClear,
  }) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                )
              : const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          value == null ? 'Not set' : DateFormat('dd MMM yyyy').format(value),
        ),
      ),
    );
  }
}
