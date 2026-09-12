import 'package:flutter/material.dart';
import 'package:policysquare/data/models/action_item.dart';
import 'package:policysquare/data/models/dashboard_summary.dart';
import 'package:policysquare/data/models/inspection_visit.dart';
import 'package:policysquare/data/models/property.dart';
import 'package:policysquare/data/repositories/commercial_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// State for the property manager workflow: property register, attendance
/// visits, and the action tracker.
class InspectionProvider with ChangeNotifier {
  final CommercialRepository _repository = CommercialRepository();

  bool _isLoading = false;
  String? _error;
  String? _mobileNumber;

  List<Property> _properties = [];
  List<InspectionVisit> _visits = [];
  List<ActionItem> _actions = [];
  DashboardSummary _summary = DashboardSummary();

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get mobileNumber => _mobileNumber;
  List<Property> get properties => _properties;
  List<InspectionVisit> get visits => _visits;
  List<ActionItem> get actions => _actions;
  DashboardSummary get summary => _summary;

  List<ActionItem> get openActions =>
      _actions.where((a) => a.status != 'CLOSED').toList();

  List<ActionItem> actionsForVisit(String visitId) =>
      _actions.where((a) => a.visitId == visitId).toList();

  Future<String?> _resolveMobile() async {
    if (_mobileNumber != null) return _mobileNumber;
    final prefs = await SharedPreferences.getInstance();
    _mobileNumber = prefs.getString('mobile_number');
    return _mobileNumber;
  }

  Future<void> loadAll() async {
    _setLoading(true);
    try {
      final mobile = await _resolveMobile();
      if (mobile == null) {
        _error = 'No signed-in user found.';
        return;
      }
      _properties = await _repository.getProperties(mobile);
      _visits = await _repository.getVisits(mobile);
      _actions = await _repository.getActions(mobile);
      _summary = await _repository.getDashboardSummary(mobile);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // --- Properties ---
  Future<Property?> addProperty(Property property) async {
    _setLoading(true);
    try {
      property.mobileNumber = await _resolveMobile();
      final result = await _repository.createProperty(property);
      _error = null;
      await loadAll();
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<Property?> updateProperty(String code, Property property) async {
    _setLoading(true);
    try {
      final result = await _repository.updateProperty(code, property);
      _error = null;
      await loadAll();
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> deleteProperty(String code) async {
    _setLoading(true);
    try {
      await _repository.deleteProperty(code);
      _error = null;
      await loadAll();
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // --- Visits ---
  Future<InspectionVisit?> addVisit(InspectionVisit visit) async {
    _setLoading(true);
    try {
      visit.mobileNumber = await _resolveMobile();
      final result = await _repository.createVisit(visit);
      _error = null;
      await loadAll();
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<InspectionVisit?> updateVisit(String id, InspectionVisit visit) async {
    _setLoading(true);
    try {
      final result = await _repository.updateVisit(id, visit);
      _error = null;
      await loadAll();
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // --- Action items ---
  Future<ActionItem?> addAction(ActionItem action) async {
    _setLoading(true);
    try {
      action.mobileNumber = await _resolveMobile();
      final result = await _repository.createAction(action);
      _error = null;
      await loadAll();
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<ActionItem?> updateAction(String id, ActionItem action) async {
    _setLoading(true);
    try {
      final result = await _repository.updateAction(id, action);
      _error = null;
      await loadAll();
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
