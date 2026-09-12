import 'package:flutter/material.dart';
import 'package:policysquare/config/inspection_guide.dart';

/// Reference scope for an attendance: what to review, what evidence to keep,
/// how often, and who is responsible by default.
class InspectionGuideScreen extends StatelessWidget {
  const InspectionGuideScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection Guide'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: InspectionGuide.entries.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Minimum review scope. Record exceptions in the visit report and '
                'unresolved work in the action tracker.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
            );
          }

          final entry = InspectionGuide.entries[index - 1];
          return Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ExpansionTile(
              leading: CircleAvatar(
                radius: 16,
                backgroundColor: const Color(0xFF1565C0).withValues(alpha: 0.1),
                child: Text(
                  entry.category.substring(0, 1),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1565C0),
                  ),
                ),
              ),
              title: Text(
                entry.component,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 14),
              ),
              subtitle: Text(
                '${entry.category} · ${entry.frequency}',
                style: const TextStyle(fontSize: 11),
              ),
              childrenPadding:
                  const EdgeInsets.fromLTRB(16, 0, 16, 16),
              expandedCrossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detail('What to review', entry.whatToReview),
                _detail('Evidence to retain', entry.evidence),
                _detail('Default responsibility', entry.responsibility),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _detail(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
                letterSpacing: 0.6,
              ),
            ),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontSize: 13)),
          ],
        ),
      );
}
