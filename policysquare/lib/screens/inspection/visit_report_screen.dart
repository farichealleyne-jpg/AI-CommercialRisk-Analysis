import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:policysquare/config/inspection_guide.dart';
import 'package:policysquare/data/models/inspection_visit.dart';
import 'package:policysquare/providers/inspection_provider.dart';
import 'package:policysquare/screens/inspection/action_tracker_screen.dart';

/// Attendance report: the record issued to the owner and asset manager after
/// each visit, and the anchor every deficiency is raised against.
class VisitReportScreen extends StatefulWidget {
  final InspectionVisit? existing;

  const VisitReportScreen({super.key, this.existing});

  @override
  State<VisitReportScreen> createState() => _VisitReportScreenState();
}

class _VisitReportScreenState extends State<VisitReportScreen> {
  static final _isoDate = DateFormat('yyyy-MM-dd');

  String? _propertyCode;
  String _inspectionType = InspectionGuide.inspectionTypes.first;
  DateTime _visitDate = DateTime.now();
  DateTime? _reportSentDate;

  final _inspectorController = TextEditingController();
  final _weatherController = TextEditingController();
  final _sentToController = TextEditingController(
    text: 'Owner and Asset Manager',
  );
  final _reportLinkController = TextEditingController();
  final _areasController = TextEditingController();
  final _conditionController = TextEditingController();
  final _operationsController = TextEditingController();
  final _revenueController = TextEditingController();
  final _immediateController = TextEditingController();
  final _decisionsController = TextEditingController();

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      _propertyCode = existing.propertyCode;
      _inspectionType = InspectionGuide.inspectionTypes
              .contains(existing.inspectionType)
          ? existing.inspectionType!
          : InspectionGuide.inspectionTypes.first;
      _visitDate = DateTime.tryParse(existing.visitDate ?? '') ?? DateTime.now();
      _reportSentDate = existing.reportSentDate == null
          ? null
          : DateTime.tryParse(existing.reportSentDate!);
      _inspectorController.text = existing.inspector ?? '';
      _weatherController.text = existing.weatherConditions ?? '';
      _sentToController.text = existing.sentTo ?? 'Owner and Asset Manager';
      _reportLinkController.text = existing.reportLink ?? '';
      _areasController.text = existing.areasInspected ?? '';
      _conditionController.text = existing.overallCondition ?? '';
      _operationsController.text = existing.operationsSummary ?? '';
      _revenueController.text = existing.revenueExpenseIssues ?? '';
      _immediateController.text = existing.immediateActions ?? '';
      _decisionsController.text = existing.decisionsRequired ?? '';
    } else {
      final properties = context.read<InspectionProvider>().properties;
      if (properties.isNotEmpty) _propertyCode = properties.first.code;
    }
  }

  @override
  void dispose() {
    _inspectorController.dispose();
    _weatherController.dispose();
    _sentToController.dispose();
    _reportLinkController.dispose();
    _areasController.dispose();
    _conditionController.dispose();
    _operationsController.dispose();
    _revenueController.dispose();
    _immediateController.dispose();
    _decisionsController.dispose();
    super.dispose();
  }

  DateTime get _reportDueDate =>
      _visitDate.add(const Duration(days: InspectionGuide.reportDueDays));

  Future<void> _save() async {
    if (_propertyCode == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a property first.')),
      );
      return;
    }

    final provider = context.read<InspectionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final visit = InspectionVisit(
      propertyCode: _propertyCode,
      visitDate: _isoDate.format(_visitDate),
      inspector: _inspectorController.text.trim(),
      inspectionType: _inspectionType,
      weatherConditions: _weatherController.text.trim(),
      reportDueDate: _isoDate.format(_reportDueDate),
      reportSentDate:
          _reportSentDate == null ? null : _isoDate.format(_reportSentDate!),
      sentTo: _sentToController.text.trim(),
      reportLink: _reportLinkController.text.trim(),
      areasInspected: _areasController.text.trim(),
      overallCondition: _conditionController.text.trim(),
      operationsSummary: _operationsController.text.trim(),
      revenueExpenseIssues: _revenueController.text.trim(),
      immediateActions: _immediateController.text.trim(),
      decisionsRequired: _decisionsController.text.trim(),
    );

    final result = _isEdit
        ? await provider.updateVisit(widget.existing!.id!, visit)
        : await provider.addVisit(visit);

    if (result != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Visit ${result.id} saved.')),
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
    final visitActions = _isEdit
        ? provider.actionsForVisit(widget.existing!.id ?? '')
        : const [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? widget.existing!.id ?? 'Visit' : 'New Visit'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionTitle('Attendance'),
          DropdownButtonFormField<String>(
            initialValue: _propertyCode,
            decoration: const InputDecoration(
              labelText: 'Property',
              border: OutlineInputBorder(),
            ),
            items: provider.properties
                .map((p) => DropdownMenuItem(
                      value: p.code,
                      child: Text('${p.code} · ${p.name}'),
                    ))
                .toList(),
            onChanged: _isEdit
                ? null
                : (value) => setState(() => _propertyCode = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _inspectionType,
            decoration: const InputDecoration(
              labelText: 'Inspection type',
              border: OutlineInputBorder(),
            ),
            items: InspectionGuide.inspectionTypes
                .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                .toList(),
            onChanged: (value) =>
                setState(() => _inspectionType = value ?? _inspectionType),
          ),
          const SizedBox(height: 12),
          _dateField(
            label: 'Visit date',
            value: _visitDate,
            onPick: (picked) => setState(() => _visitDate = picked),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _inspectorController,
            decoration: const InputDecoration(
              labelText: 'Inspector',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _weatherController,
            decoration: const InputDecoration(
              labelText: 'Weather / conditions',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),
          _sectionTitle('Reporting'),
          Card(
            color: const Color(0xFFE3F2FD),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  const Icon(Icons.schedule, size: 18, color: Color(0xFF1565C0)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Report due ${DateFormat('dd MMM yyyy').format(_reportDueDate)} '
                      '(${InspectionGuide.reportDueDays} days after attendance)',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _sentToController,
            decoration: const InputDecoration(
              labelText: 'Recipients',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          _dateField(
            label: 'Report sent date',
            value: _reportSentDate,
            allowClear: true,
            onPick: (picked) => setState(() => _reportSentDate = picked),
            onClear: () => setState(() => _reportSentDate = null),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _reportLinkController,
            decoration: const InputDecoration(
              labelText: 'Report / folder link',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),
          _sectionTitle('Findings'),
          _narrative('Areas inspected', _areasController),
          _narrative('Overall condition and material findings',
              _conditionController),
          _narrative('Operations and tenant matters', _operationsController),
          _narrative('Revenue and expense issues', _revenueController),
          _narrative('Immediate actions taken', _immediateController),
          _narrative('Decisions and approvals required', _decisionsController),

          if (_isEdit) ...[
            const SizedBox(height: 12),
            _sectionTitle('Actions raised'),
            if (visitActions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No deficiencies recorded against this visit yet.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              )
            else
              ...visitActions.map(
                (a) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    a.safetyHazard == true
                        ? Icons.warning_amber_rounded
                        : Icons.circle,
                    size: 16,
                    color: a.safetyHazard == true ? Colors.red : Colors.indigo,
                  ),
                  title: Text(a.issue ?? '', style: const TextStyle(fontSize: 13)),
                  subtitle: Text(
                    '${a.id} · ${InspectionGuide.statusLabel(a.status)}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActionTrackerScreen(
                    visitId: widget.existing!.id,
                    propertyCode: widget.existing!.propertyCode,
                  ),
                ),
              ),
              icon: const Icon(Icons.add_task, size: 18),
              label: const Text('Raise / review actions for this visit'),
            ),
          ],

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
                  : Text(_isEdit ? 'SAVE CHANGES' : 'SAVE VISIT'),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
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

  Widget _narrative(String label, TextEditingController controller) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: label,
            alignLabelWithHint: true,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  Widget _dateField({
    required String label,
    required DateTime? value,
    required ValueChanged<DateTime> onPick,
    bool allowClear = false,
    VoidCallback? onClear,
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
          suffixIcon: allowClear && value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: onClear,
                )
              : const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          value == null
              ? 'Not set'
              : DateFormat('dd MMM yyyy').format(value),
        ),
      ),
    );
  }
}
