import 'package:policysquare/api/api_client.dart';
import 'package:policysquare/api/api_service.dart';
import 'package:policysquare/data/models/risk_assessment.dart';
import 'package:policysquare/data/models/rfq.dart';
import 'package:policysquare/data/models/claim_story.dart';
import 'package:policysquare/data/models/underwriting_tip.dart';
import 'package:policysquare/data/models/health_quote_request.dart';
import 'package:policysquare/data/models/health_quote_response.dart';
import 'package:policysquare/data/models/property_budget.dart';

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
}
