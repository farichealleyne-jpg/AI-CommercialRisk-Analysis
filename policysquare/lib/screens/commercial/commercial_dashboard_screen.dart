import 'package:flutter/material.dart';
import 'package:policysquare/screens/commercial/claims_list_screen.dart';
import 'package:policysquare/screens/commercial/underwriting_tips_screen.dart';

import 'package:policysquare/screens/commercial/rfq_screen.dart';
import 'package:policysquare/screens/commercial/inspection_selection_screen.dart';
import 'package:policysquare/screens/commercial/property_budget_screen.dart';

class CommercialDashboardScreen extends StatelessWidget {
  const CommercialDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commercial Insurance'), elevation: 1),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              children: [
                _buildDashboardCard(
                  context,
                  title: 'Inspection Report',
                  icon: Icons.assignment, // Or assignment_turned_in
                  color: Colors.orange,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const InspectionSelectionScreen(),
                      ),
                    );
                  },
                ),
                _buildDashboardCard(
                  context,
                  title: 'Request Quote (RFQ)',
                  icon: Icons.request_quote,
                  color: Colors.blue,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RfqScreen()),
                    );
                  },
                ),
                _buildDashboardCard(
                  context,
                  title: 'Footprints of Claims',
                  icon: Icons.history_edu,
                  color: Colors.purple,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const ClaimsListScreen(category: 'Commercial'),
                      ),
                    );
                  },
                ),
                _buildDashboardCard(
                  context,
                  title: 'Fineprint of UnderWriting',
                  icon: Icons.lightbulb_outline,
                  color: Colors.green,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const UnderwritingTipsScreen(
                          category: 'Commercial',
                        ),
                      ),
                    );
                  },
                ),
                _buildDashboardCard(
                  context,
                  title: 'Property Budget',
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
          ],
        ),
      ),
    );
  }

  // Helper for grid items
  Widget _buildDashboardCard(
    BuildContext context, {
    required String title,
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
