import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:policysquare/data/models/property.dart';
import 'package:policysquare/providers/inspection_provider.dart';

class PropertyRegisterScreen extends StatelessWidget {
  const PropertyRegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Property Register'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showPropertyDialog(context),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add property'),
      ),
      body: Consumer<InspectionProvider>(
        builder: (context, provider, _) {
          if (provider.isLoading && provider.properties.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (provider.properties.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.apartment, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No properties yet',
                      style: TextStyle(fontSize: 18, color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Add a property to start recording attendance visits and deficiencies against it.',
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
            itemCount: provider.properties.length,
            itemBuilder: (context, index) {
              final property = provider.properties[index];
              final visitCount = provider.visits
                  .where((v) => v.propertyCode == property.code)
                  .length;
              final openCount = provider.openActions
                  .where((a) => a.propertyCode == property.code)
                  .length;
              final inactive = property.status == 'INACTIVE';

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: inactive
                        ? Colors.grey.shade300
                        : const Color(0xFF1565C0),
                    child: Text(
                      property.code ?? '?',
                      style: TextStyle(
                        color: inactive ? Colors.grey.shade700 : Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(
                          property.name ?? 'Unnamed',
                          style:
                              const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      if (inactive) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('Inactive',
                              style: TextStyle(fontSize: 10)),
                        ),
                      ],
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 2),
                      Text(property.displayAddress,
                          style: const TextStyle(fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(
                        '$visitCount ${visitCount == 1 ? "visit" : "visits"} · $openCount open ${openCount == 1 ? "action" : "actions"}',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'edit') {
                        _showPropertyDialog(context, existing: property);
                      } else if (value == 'delete') {
                        _confirmDelete(context, property);
                      }
                    },
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'delete', child: Text('Delete')),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Property property) async {
    final provider = context.read<InspectionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete property?'),
        content: Text(
          'Remove ${property.name ?? property.code} from the register? '
          'Visits and actions already recorded against it are not deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final ok = await provider.deleteProperty(property.code!);
      messenger.showSnackBar(
        SnackBar(
          content: Text(ok
              ? 'Property deleted.'
              : 'Could not delete: ${provider.error ?? "unknown error"}'),
          backgroundColor: ok ? null : Colors.red,
        ),
      );
    }
  }

  Future<void> _showPropertyDialog(
    BuildContext context, {
    Property? existing,
  }) async {
    final provider = context.read<InspectionProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final isEdit = existing != null;

    final codeController = TextEditingController(text: existing?.code ?? '');
    final nameController = TextEditingController(text: existing?.name ?? '');
    final addressController =
        TextEditingController(text: existing?.addressLine ?? '');
    final cityController = TextEditingController(text: existing?.city ?? '');
    final regionController =
        TextEditingController(text: existing?.region ?? '');
    final notesController = TextEditingController(text: existing?.notes ?? '');
    String status = existing?.status ?? 'ACTIVE';

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit property' : 'Add property'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: codeController,
                  enabled: !isEdit,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Property code',
                    hintText: 'e.g. RR',
                    helperText: 'Short code used to prefix visit and action IDs',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: 'Property name',
                    hintText: 'e.g. River Road',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: addressController,
                  decoration: const InputDecoration(labelText: 'Address'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: cityController,
                  decoration: const InputDecoration(labelText: 'City'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: regionController,
                  decoration:
                      const InputDecoration(labelText: 'Province / State'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: 'Status'),
                  items: const [
                    DropdownMenuItem(value: 'ACTIVE', child: Text('Active')),
                    DropdownMenuItem(
                        value: 'INACTIVE', child: Text('Inactive')),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => status = value ?? status),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (codeController.text.trim().isEmpty ||
                    nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Property code and name are required.'),
                    ),
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              child: Text(isEdit ? 'Save' : 'Add'),
            ),
          ],
        ),
      ),
    );

    if (saved != true) return;

    final property = Property(
      code: codeController.text.trim().toUpperCase(),
      name: nameController.text.trim(),
      addressLine: addressController.text.trim(),
      city: cityController.text.trim(),
      region: regionController.text.trim(),
      status: status,
      notes: notesController.text.trim(),
    );

    final result = isEdit
        ? await provider.updateProperty(existing.code!, property)
        : await provider.addProperty(property);

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          result != null
              ? '${result.name} saved.'
              : 'Could not save: ${provider.error ?? "unknown error"}',
        ),
        backgroundColor: result != null ? null : Colors.red,
      ),
    );
  }
}
