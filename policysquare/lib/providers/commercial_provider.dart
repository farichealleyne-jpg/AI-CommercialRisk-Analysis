import 'package:flutter/material.dart';
import 'package:policysquare/data/models/risk_assessment.dart';
import 'package:policysquare/data/models/rfq.dart';
import 'package:policysquare/data/models/claim_story.dart';
import 'package:policysquare/data/models/underwriting_tip.dart';
import 'package:policysquare/data/models/health_quote_request.dart';
import 'package:policysquare/data/models/health_quote_response.dart';
import 'package:policysquare/data/models/property_budget.dart';
import 'package:policysquare/data/repositories/commercial_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CommercialProvider with ChangeNotifier {
  final CommercialRepository _repository = CommercialRepository();

  // State
  bool _isLoading = false;
  String? _error;
  String? _mobileNumber;

  List<ClaimStory> _stories = [];
  List<UnderwritingTip> _tips = [];
  List<RiskAssessment> _assessmentHistory = [];
  List<Rfq> _rfqHistory = [];
  List<HealthQuoteResponse> _healthQuotes = [];
  List<PropertyBudget> _budgetHistory = [];

  // Getters
  bool get isLoading => _isLoading;
  String? get error => _error;
  List<ClaimStory> get stories => _stories;
  List<UnderwritingTip> get tips => _tips;
  List<RiskAssessment> get assessmentHistory => _assessmentHistory;
  List<Rfq> get rfqHistory => _rfqHistory;
  List<HealthQuoteResponse> get healthQuotes => _healthQuotes;
  List<PropertyBudget> get budgetHistory => _budgetHistory;

  // --- Actions ---

  // Fetch Claim Stories
  Future<void> fetchStories({String? category}) async {
    _setLoading(true);
    try {
      _stories = await _repository.getClaimStories(category: category);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Fetch Underwriting Tips
  Future<void> fetchTips({String? category}) async {
    _setLoading(true);
    try {
      _tips = await _repository.getUnderwritingTips(category: category);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Calculate Health Quotes
  Future<void> calculateHealthQuotes(HealthQuoteRequest request) async {
    _setLoading(true);
    try {
      _healthQuotes = await _repository.calculateHealthQuotes(request);
      _error = null;
    } catch (e) {
      _error = e.toString();
      _healthQuotes = [];
    } finally {
      _setLoading(false);
    }
  }

  // Submit RFQ
  Future<bool> submitRfq(Rfq rfq) async {
    _setLoading(true);
    try {
      await _repository.submitRfq(rfq);
      _error = null;
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadMobileNumber() async {
    final prefs = await SharedPreferences.getInstance();
    _mobileNumber = prefs.getString('mobile_number');
    if (_mobileNumber != null) {
      await fetchHistory(_mobileNumber!);
    }
    notifyListeners();
  }

  // Submit Risk Assessment
  Future<RiskAssessment?> submitAssessment(RiskAssessment assessment) async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final mobile = prefs.getString('mobile_number');

      // Ensure mobile number is attached
      assessment.mobileNumber = mobile ?? assessment.mobileNumber;

      final result = await _repository.submitAssessment(assessment);
      _error = null;
      if (mobile != null) fetchHistory(mobile); // Refresh history
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // Fetch History (Mock mobile for now if auth not ready)
  Future<void> fetchHistory(String mobile) async {
    _setLoading(true);
    try {
      _assessmentHistory = await _repository.getAssessmentHistory(mobile);
      _rfqHistory = await _repository.getUserRfqs(mobile);
      _budgetHistory = await _repository.getPropertyBudgetHistory(mobile);
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _setLoading(false);
    }
  }

  // Submit Property Budget
  Future<PropertyBudget?> submitPropertyBudget(PropertyBudget budget) async {
    _setLoading(true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final mobile = prefs.getString('mobile_number');

      budget.mobileNumber = mobile ?? budget.mobileNumber;

      final result = await _repository.submitPropertyBudget(budget);
      _error = null;
      if (mobile != null) fetchHistory(mobile);
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<PropertyBudget?> updatePropertyBudget(
    String id,
    PropertyBudget budget,
  ) async {
    _setLoading(true);
    try {
      final result = await _repository.updatePropertyBudget(id, budget);
      _error = null;
      return result;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<RiskAssessment?> fetchAssessmentById(String id) async {
    _setLoading(true);
    try {
      final result = await _repository.getAssessmentById(id);
      _error = null;
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
