import 'package:policysquare/api/api_client.dart';
import 'package:policysquare/api/api_service.dart';
import 'package:policysquare/data/models/risk_assessment.dart';
import 'package:policysquare/data/models/rfq.dart';
import 'package:policysquare/data/models/claim_story.dart';
import 'package:policysquare/data/models/underwriting_tip.dart';
import 'package:policysquare/data/models/health_quote_request.dart';
import 'package:policysquare/data/models/health_quote_response.dart';
import 'package:policysquare/data/models/property_budget.dart';
import 'package:policysquare/data/models/property.dart';
import 'package:policysquare/data/models/inspection_visit.dart';
import 'package:policysquare/data/models/action_item.dart';
import 'package:policysquare/data/models/dashboard_summary.dart';

class CommercialRepository {
  late final ApiService _apiService;

  CommercialRepository() {
    _apiService = ApiService(ApiClient().dio);
  }

  // --- Risk Assessment ---
  Future<RiskAssessment> submitAssessment(RiskAssessment assessment) async {
    return await _apiService.createAssessment(assessment);
  }

  Future<List<RiskAssessment>> getAssessmentHistory(String mobile) async {
    return await _apiService.getAssessmentsByUser(mobile);
  }

  Future<RiskAssessment> getAssessmentById(String id) async {
    return await _apiService.getAssessmentById(id);
  }

  // --- RFQ ---
  Future<Rfq> submitRfq(Rfq rfq) async {
    return await _apiService.submitRfq(rfq);
  }

  Future<List<Rfq>> getUserRfqs(String mobile) async {
    return await _apiService.getUserRfqs(mobile);
  }

  // --- Claims ---
  Future<List<ClaimStory>> getClaimStories({String? category}) async {
    return await _apiService.getStories(category: category);
  }

  // --- Underwriting Tips ---
  Future<List<UnderwritingTip>> getUnderwritingTips({String? category}) async {
    return await _apiService.getUnderwritingTips(category: category);
  }

  // --- Health Quotes ---
  Future<List<HealthQuoteResponse>> calculateHealthQuotes(
    HealthQuoteRequest request,
  ) async {
    return await _apiService.calculateHealthQuotes(request);
  }

  // --- Property Budget ---
  Future<PropertyBudget> submitPropertyBudget(PropertyBudget budget) async {
    return await _apiService.createPropertyBudget(budget);
  }

  Future<List<PropertyBudget>> getPropertyBudgetHistory(String mobile) async {
    return await _apiService.getPropertyBudgetsByUser(mobile);
  }

  Future<PropertyBudget> getPropertyBudgetById(String id) async {
    return await _apiService.getPropertyBudgetById(id);
  }

  Future<PropertyBudget> updatePropertyBudget(
    String id,
    PropertyBudget budget,
  ) async {
    return await _apiService.updatePropertyBudget(id, budget);
  }

  // --- Properties ---
  Future<Property> createProperty(Property property) async {
    return await _apiService.createProperty(property);
  }

  Future<List<Property>> getProperties(String mobile) async {
    return await _apiService.getPropertiesByUser(mobile);
  }

  Future<Property> updateProperty(String code, Property property) async {
    return await _apiService.updateProperty(code, property);
  }

  Future<void> deleteProperty(String code) async {
    return await _apiService.deleteProperty(code);
  }

  // --- Inspection visits ---
  Future<InspectionVisit> createVisit(InspectionVisit visit) async {
    return await _apiService.createVisit(visit);
  }

  Future<List<InspectionVisit>> getVisits(String mobile) async {
    return await _apiService.getVisitsByUser(mobile);
  }

  Future<InspectionVisit> updateVisit(String id, InspectionVisit visit) async {
    return await _apiService.updateVisit(id, visit);
  }

  // --- Action items ---
  Future<ActionItem> createAction(ActionItem action) async {
    return await _apiService.createAction(action);
  }

  Future<List<ActionItem>> getActions(String mobile) async {
    return await _apiService.getActionsByUser(mobile);
  }

  Future<List<ActionItem>> getActionsByVisit(String visitId) async {
    return await _apiService.getActionsByVisit(visitId);
  }

  Future<ActionItem> updateAction(String id, ActionItem action) async {
    return await _apiService.updateAction(id, action);
  }

  Future<DashboardSummary> getDashboardSummary(String mobile) async {
    return await _apiService.getDashboardSummary(mobile);
  }
}
