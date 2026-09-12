import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:policysquare/data/models/inspection_visit.dart';
import 'package:policysquare/providers/inspection_provider.dart';
import 'package:policysquare/screens/inspection/visit_report_screen.dart';

class VisitLogScreen extends StatelessWidget {
  const VisitLogScreen({super.key});

  static String formatDate(String? iso) {
    if (iso == null || iso.isEmpty) return '—';
    final parsed = DateTime.tryParse(iso);
    if (parsed == null) return iso;
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Visit Log'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: Consumer<InspectionProvider>(
        builder: (context, provider, _) => FloatingActionButton.extended(
          onPressed: provider.properties.isEmpty
              ? () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Add a property in the register before recording a visit.',
                      ),
                    ),
                  )
              : () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const VisitReportScreen(),
                    ),
                  ),
          backgroundColor: const Color(0xFF1565C0),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('New visit'),
        ),
      ),
      body: Consumer<InspectionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.visits.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.visits.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.event_note, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No visits recorded',
                        style: TextStyle(fontSize: 18, color: Colors.grey)),
                    SizedBox(height: 8),
                    Text(
                      'Record an attendance to start the reporting clock and raise deficiencies against it.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: provider.visits.length,
            itemBuilder: (context, index) {
              final visit = provider.visits[index];
              final actionCount =
                  provider.actionsForVisit(visit.id ?? '').length;
              return _visitCard(context, visit, actionCount);
            },
          );
        },
      ),
    );
  }

  Widget _visitCard(
    BuildContext context,
    InspectionVisit visit,
    int actionCount,
  ) {
    final status = visit.reportStatus ?? 'PENDING';
    final (statusColor, statusLabel) = switch (status) {
      'SENT' => (const Color(0xFF2E7D32), 'Report sent'),
      'OVERDUE' => (const Color(0xFFC62828), 'Report overdue'),
      _ => (const Color(0xFFEF6C00), 'Report due'),
    };

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => VisitReportScreen(existing: visit),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      visit.id ?? '—',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '${visit.inspectionType ?? "Attendance"} · ${VisitLogScreen.formatDate(visit.visitDate)}',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Inspector: ${visit.inspector?.isNotEmpty == true ? visit.inspector : "—"}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                visit.reportSentDate != null && visit.reportSentDate!.isNotEmpty
                    ? 'Sent ${VisitLogScreen.formatDate(visit.reportSentDate)} to ${visit.sentTo ?? "recipients"}'
                    : 'Due ${VisitLogScreen.formatDate(visit.reportDueDate)}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              if (actionCount > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.checklist,
                        size: 14, color: Colors.indigo),
                    const SizedBox(width: 6),
                    Text(
                      '$actionCount ${actionCount == 1 ? "action" : "actions"} raised',
                      style: const TextStyle(
                          fontSize: 12, color: Colors.indigo),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
