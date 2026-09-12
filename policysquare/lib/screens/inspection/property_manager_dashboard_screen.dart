import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:policysquare/providers/inspection_provider.dart';
import 'package:policysquare/screens/inspection/action_tracker_screen.dart';
import 'package:policysquare/screens/inspection/inspection_guide_screen.dart';
import 'package:policysquare/screens/inspection/property_register_screen.dart';
import 'package:policysquare/screens/inspection/visit_log_screen.dart';

class PropertyManagerDashboardScreen extends StatefulWidget {
  const PropertyManagerDashboardScreen({super.key});

  @override
  State<PropertyManagerDashboardScreen> createState() =>
      _PropertyManagerDashboardScreenState();
}

class _PropertyManagerDashboardScreenState
    extends State<PropertyManagerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<InspectionProvider>().loadAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(symbol: '\$', decimalDigits: 0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Management'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () => context.read<InspectionProvider>().loadAll(),
          ),
        ],
      ),
      body: Consumer<InspectionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.properties.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          final summary = provider.summary;

          return RefreshIndicator(
            onRefresh: provider.loadAll,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Attendance, reports, deficiencies and approvals across ${provider.properties.length} '
                  '${provider.properties.length == 1 ? "property" : "properties"}.',
                  style: const TextStyle(fontSize: 13, color: Colors.grey),
                ),
                const SizedBox(height: 16),

                // Headline controls
                Row(
                  children: [
                    _metric('Visits', '${summary.visits}', Colors.blueGrey),
                    const SizedBox(width: 8),
                    _metric('Reports due', '${summary.reportsPending}',
                        Colors.blue),
                    const SizedBox(width: 8),
                    _metric('Reports overdue', '${summary.reportsOverdue}',
                        summary.reportsOverdue > 0 ? Colors.red : Colors.grey),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _metric('Open actions', '${summary.openActions}',
                        Colors.indigo),
                    const SizedBox(width: 8),
                    _metric(
                      'Safety hazards',
                      '${summary.openSafetyHazards}',
                      summary.openSafetyHazards > 0
                          ? Colors.red
                          : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    _metric('Overdue', '${summary.overdueActions}',
                        summary.overdueActions > 0 ? Colors.orange : Colors.grey),
                  ],
                ),
                const SizedBox(height: 16),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Open work by priority',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        _priorityRow('Critical', summary.criticalOpen,
                            const Color(0xFFC62828)),
                        _priorityRow(
                            'High', summary.highOpen, const Color(0xFFEF6C00)),
                        _priorityRow('Medium', summary.mediumOpen,
                            const Color(0xFFF9A825)),
                        _priorityRow(
                            'Low', summary.lowOpen, const Color(0xFF2E7D32)),
                        const Divider(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Estimated open cost'),
                            Text(
                              currency.format(summary.estimatedOpenCost),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1565C0),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Items needing capital review'),
                            Text(
                              '${summary.capitalReviews}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: summary.capitalReviews > 0
                                    ? const Color(0xFFC62828)
                                    : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                _navTile(
                  context,
                  title: 'Property register',
                  subtitle:
                      '${provider.properties.length} recorded · add or edit properties',
                  icon: Icons.apartment,
                  color: Colors.teal,
                  screen: const PropertyRegisterScreen(),
                ),
                _navTile(
                  context,
                  title: 'Visit log',
                  subtitle: '${provider.visits.length} attendances recorded',
                  icon: Icons.event_note,
                  color: Colors.blue,
                  screen: const VisitLogScreen(),
                ),
                _navTile(
                  context,
                  title: 'Action tracker',
                  subtitle:
                      '${provider.openActions.length} open of ${provider.actions.length} total',
                  icon: Icons.checklist,
                  color: Colors.indigo,
                  screen: const ActionTrackerScreen(),
                ),
                _navTile(
                  context,
                  title: 'Inspection guide',
                  subtitle: 'Minimum review scope by category',
                  icon: Icons.menu_book,
                  color: Colors.brown,
                  screen: const InspectionGuideScreen(),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _metric(String label, String value, Color color) {
    return Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          child: Column(
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _priorityRow(String label, int count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(
            '$count',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _navTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required Widget screen,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.12),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => screen),
        ),
      ),
    );
  }
}
