/// Minimum review scope for a property attendance, and the category taxonomy
/// used when raising action items.
class InspectionGuideEntry {
  final String category;
  final String component;
  final String whatToReview;
  final String evidence;
  final String frequency;
  final String responsibility;

  const InspectionGuideEntry({
    required this.category,
    required this.component,
    required this.whatToReview,
    required this.evidence,
    required this.frequency,
    required this.responsibility,
  });
}

class InspectionGuide {
  /// Report is due this many calendar days after attendance.
  static const int reportDueDays = 5;

  /// Work expected to exceed this requires the capital-approval process.
  static const double capitalReviewThreshold = 10000;

  static const List<InspectionGuideEntry> entries = [
    InspectionGuideEntry(
      category: 'Public areas',
      component: 'Entrances, sidewalks and common areas',
      whatToReview:
          'Cleanliness, obstructions, damage, public access and immediate hazards',
      evidence: 'Photos for exceptions',
      frequency: 'Every visit',
      responsibility: 'Landlord',
    ),
    InspectionGuideEntry(
      category: 'Paving',
      component: 'Asphalt, curbs and sidewalks',
      whatToReview:
          'Potholes, cracks, settlement, drainage, line painting and trip hazards',
      evidence: 'Location photos and measurements',
      frequency: 'Every visit / spring review',
      responsibility: 'Landlord',
    ),
    InspectionGuideEntry(
      category: 'Winter',
      component: 'Snow and ice',
      whatToReview:
          'Accumulation, salting, access routes, piles, drainage and contractor performance',
      evidence: 'Event photos and service record',
      frequency: 'Winter / after events',
      responsibility: 'Landlord',
    ),
    InspectionGuideEntry(
      category: 'Lighting',
      component: 'Exterior lights and poles',
      whatToReview:
          'Burnt-out fixtures, pole condition, photocells, dark areas and tenant impact',
      evidence: 'Night-audit photos',
      frequency: 'Night audit / every visit',
      responsibility: 'Landlord / lease review',
    ),
    InspectionGuideEntry(
      category: 'Roof',
      component: 'Roofs and roof drainage',
      whatToReview:
          'Membrane, flashing, penetrations, debris, drains, scuppers and leak evidence',
      evidence: 'Roof report and photos',
      frequency: 'Seasonal / after major weather',
      responsibility: 'Landlord',
    ),
    InspectionGuideEntry(
      category: 'Stormwater',
      component: 'Catch basins and drainage',
      whatToReview:
          'Blockage, ponding, sediment, damaged structures and cleanout needs',
      evidence: 'Photos, inspection and cleanout record',
      frequency: 'Spring / fall / after storms',
      responsibility: 'Landlord',
    ),
    InspectionGuideEntry(
      category: 'Envelope',
      component: 'Masonry',
      whatToReview:
          'Cracking, failed mortar, sealant, spalling, movement and localized replacement needs',
      evidence: 'Elevation photos and consultant report',
      frequency: 'Every visit / annual detailed review',
      responsibility: 'Landlord',
    ),
    InspectionGuideEntry(
      category: 'Envelope',
      component: 'Siding, soffits and exterior finishes',
      whatToReview:
          'Loose, damaged or deteriorated components and water-entry indicators',
      evidence: 'Photos and scope notes',
      frequency: 'Every visit',
      responsibility: 'Landlord',
    ),
    InspectionGuideEntry(
      category: 'Tenancies',
      component: 'Storefronts and vacant units',
      whatToReview:
          'Damage, housekeeping, unauthorized work, vacant-unit security and readiness',
      evidence: 'Unit photos and tenant correspondence',
      frequency: 'Every visit / turnover',
      responsibility: 'Tenant / lease review',
    ),
    InspectionGuideEntry(
      category: 'Mechanical',
      component: 'HVAC and mechanical areas',
      whatToReview:
          'Operating condition, leaks, housekeeping, access, maintenance labels and tenant-maintained equipment',
      evidence: 'Service records and photos',
      frequency: 'Seasonal / every visit',
      responsibility: 'Landlord / tenant by lease',
    ),
    InspectionGuideEntry(
      category: 'Electrical',
      component: 'Electrical rooms and equipment',
      whatToReview:
          'Access, housekeeping, panel condition, water exposure and temporary wiring',
      evidence: 'Photos and service report',
      frequency: 'Every visit',
      responsibility: 'Landlord / tenant by lease',
    ),
    InspectionGuideEntry(
      category: 'Utilities',
      component: 'Water, sewer and plumbing',
      whatToReview:
          'Leaks, abnormal use indicators, meter condition, shutoffs and plumbing deficiencies',
      evidence: 'Meter photos and work records',
      frequency: 'Every visit / billing exception',
      responsibility: 'Landlord / tenant by lease',
    ),
    InspectionGuideEntry(
      category: 'Compliance',
      component: 'Backflow prevention',
      whatToReview:
          'Device condition, test tag, annual certification and outstanding deficiencies',
      evidence: 'Certificate and deficiency report',
      frequency: 'Annual / due date',
      responsibility: 'Landlord / lease review',
    ),
    InspectionGuideEntry(
      category: 'Life safety',
      component: 'Fire and life-safety systems',
      whatToReview:
          'Certificates, panel status, extinguishers, alarms, sprinkler components, exits and deficiencies',
      evidence: 'Certificates, reports and work orders',
      frequency: 'Every visit / scheduled testing',
      responsibility: 'Landlord / tenant by lease',
    ),
    InspectionGuideEntry(
      category: 'Waste',
      component: 'Compactor and garbage area',
      whatToReview:
          'Equipment condition, leakage, odour, housekeeping, access, misuse and repair needs',
      evidence: 'Photos and service report',
      frequency: 'Every visit',
      responsibility: 'Landlord / tenant by arrangement',
    ),
    InspectionGuideEntry(
      category: 'Site',
      component: 'Landscaping',
      whatToReview:
          'Plant health, irrigation, weeds, sightlines, dead limbs and contractor performance',
      evidence: 'Photos and service record',
      frequency: 'Growing season',
      responsibility: 'Landlord',
    ),
    InspectionGuideEntry(
      category: 'Site',
      component: 'Pylons, signs and bike racks',
      whatToReview:
          'Structural condition, panels, paint, lighting, management details, anchoring and obstructions',
      evidence: 'Photos and scope notes',
      frequency: 'Every visit',
      responsibility: 'Landlord / tenant signage',
    ),
    InspectionGuideEntry(
      category: 'Accessibility',
      component: 'Accessible routes and trip hazards',
      whatToReview:
          'Parking, curb cuts, doors, paths, slopes, obstructions and surface transitions',
      evidence: 'Photos and measurements',
      frequency: 'Every visit',
      responsibility: 'Landlord',
    ),
    InspectionGuideEntry(
      category: 'Environmental',
      component: 'Spills and environmental conditions',
      whatToReview:
          'Leaks, stains, storage, odours, waste handling and possible environmental concerns',
      evidence: 'Incident record and photos',
      frequency: 'Every visit / incident',
      responsibility: 'Landlord / responsible party',
    ),
    InspectionGuideEntry(
      category: 'Lease compliance',
      component: 'Tenant obligations',
      whatToReview:
          'HVAC maintenance, insurance, repairs, signage, waste, unauthorized work and other visible obligations',
      evidence: 'Lease clause and correspondence',
      frequency: 'Every visit',
      responsibility: 'Tenant / lease review',
    ),
    InspectionGuideEntry(
      category: 'Security',
      component: 'Cameras, locks and access',
      whatToReview:
          'Camera operation, remote access, locks, gates, keys, blind spots and vandalism',
      evidence: 'Access record and photos',
      frequency: 'Every visit / incident',
      responsibility: 'Landlord',
    ),
    InspectionGuideEntry(
      category: 'Capital',
      component: 'Active and future projects',
      whatToReview:
          'Condition progression, contractor work, disruption, deficiencies, warranty and closeout',
      evidence: 'Progress photos and project records',
      frequency: 'Each project visit',
      responsibility: 'Landlord',
    ),
  ];

  /// Distinct categories, in guide order, for action-item classification.
  static List<String> get categories {
    final seen = <String>[];
    for (final entry in entries) {
      if (!seen.contains(entry.category)) seen.add(entry.category);
    }
    return seen;
  }

  static const List<String> inspectionTypes = [
    'Routine attendance',
    'Seasonal review',
    'Night audit',
    'Post-event / storm',
    'Project / capital visit',
    'Incident follow-up',
  ];

  static const List<String> priorities = ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW'];

  static const List<String> actionStatuses = [
    'OPEN',
    'QUOTE_REQUESTED',
    'APPROVED',
    'IN_PROGRESS',
    'VERIFIED',
    'CLOSED',
  ];

  static const List<String> responsibleParties = [
    'Landlord',
    'Tenant',
    'Contractor',
    'Consultant',
    'Lease review',
  ];

  static String statusLabel(String? raw) {
    switch (raw) {
      case 'QUOTE_REQUESTED':
        return 'Quote requested';
      case 'IN_PROGRESS':
        return 'In progress';
      case 'NOT_REQUIRED':
        return 'Not required';
      case null:
        return 'Open';
      default:
        final lower = raw.toLowerCase().replaceAll('_', ' ');
        return lower[0].toUpperCase() + lower.substring(1);
    }
  }
}
