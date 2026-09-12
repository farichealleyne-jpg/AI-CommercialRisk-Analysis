import 'package:flutter/material.dart';
import 'package:policysquare/screens/commercial/inspection_report_screen.dart';
import 'package:policysquare/screens/commercial/risk_assessment_history_screen.dart';
import 'package:policysquare/screens/commercial/property_budget_screen.dart';
import 'package:policysquare/screens/inspection/property_manager_dashboard_screen.dart';

class InspectionSelectionScreen extends StatelessWidget {
  const InspectionSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inspection Report'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildWideCard(
              context,
              title: 'Property Management',
              subtitle:
                  'Attendance visits, deficiencies, approvals and property register',
              icon: Icons.apartment,
              color: const Color(0xFF1565C0),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PropertyManagerDashboardScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildWideCard(
              context,
              title: 'Start Risk Assessment',
              subtitle: 'Provide property details and generate score',
              icon: Icons.assignment,
              color: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const InspectionReportScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildWideCard(
              context,
              title: 'View Risk Assessment',
              subtitle: 'View previous risk assessments',
              icon: Icons.assignment_turned_in,
              color: Colors.indigo,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const RiskAssessmentHistoryScreen(),
                  ),
                );
              },
            ),
            const SizedBox(height: 16),
            _buildWideCard(
              context,
              title: 'Property Budget',
              subtitle: 'Itemize repair and maintenance costs for a property',
              icon: Icons.account_balance_wallet,
              color: Colors.teal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const PropertyBudgetScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
