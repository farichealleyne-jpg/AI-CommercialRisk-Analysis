import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
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

part 'api_service.g.dart';

@RestApi()
abstract class ApiService {
  factory ApiService(Dio dio, {String baseUrl}) = _ApiService;

  // --- Risk Assessment ---
  @POST("/api/risk-assessments")
  Future<RiskAssessment> createAssessment(@Body() RiskAssessment assessment);

  @GET("/api/risk-assessments/user/{mobile}")
  Future<List<RiskAssessment>> getAssessmentsByUser(
    @Path("mobile") String mobile,
  );

  @GET("/api/risk-assessments/{id}")
  Future<RiskAssessment> getAssessmentById(@Path("id") String id);

  // --- RFQ ---
  @POST("/api/rfq")
  Future<Rfq> submitRfq(@Body() Rfq rfq);

  @GET("/api/rfq/user/{mobile}")
  Future<List<Rfq>> getUserRfqs(@Path("mobile") String mobile);

  // --- Claims ---
  @GET("/api/claims/stories")
  Future<List<ClaimStory>> getStories({@Query("category") String? category});

  // --- Underwriting Tips ---
  @GET("/api/underwriting/tips")
  Future<List<UnderwritingTip>> getUnderwritingTips({
    @Query("category") String? category,
  });

  @POST("/api/health/quotes/calculate")
  Future<List<HealthQuoteResponse>> calculateHealthQuotes(
    @Body() HealthQuoteRequest request,
  );

  // --- Property Budget ---
  @POST("/api/property-budgets")
  Future<PropertyBudget> createPropertyBudget(@Body() PropertyBudget budget);

  @GET("/api/property-budgets/user/{mobile}")
  Future<List<PropertyBudget>> getPropertyBudgetsByUser(
    @Path("mobile") String mobile,
  );

  @GET("/api/property-budgets/{id}")
  Future<PropertyBudget> getPropertyBudgetById(@Path("id") String id);

  @PUT("/api/property-budgets/{id}")
  Future<PropertyBudget> updatePropertyBudget(
    @Path("id") String id,
    @Body() PropertyBudget budget,
  );

  // --- Properties ---
  @POST("/api/properties")
  Future<Property> createProperty(@Body() Property property);

  @GET("/api/properties/user/{mobile}")
  Future<List<Property>> getPropertiesByUser(@Path("mobile") String mobile);

  @PUT("/api/properties/{code}")
  Future<Property> updateProperty(
    @Path("code") String code,
    @Body() Property property,
  );

  @DELETE("/api/properties/{code}")
  Future<void> deleteProperty(@Path("code") String code);

  // --- Inspection visits ---
  @POST("/api/visits")
  Future<InspectionVisit> createVisit(@Body() InspectionVisit visit);

  @GET("/api/visits/user/{mobile}")
  Future<List<InspectionVisit>> getVisitsByUser(@Path("mobile") String mobile);

  @GET("/api/visits/{id}")
  Future<InspectionVisit> getVisitById(@Path("id") String id);

  @PUT("/api/visits/{id}")
  Future<InspectionVisit> updateVisit(
    @Path("id") String id,
    @Body() InspectionVisit visit,
  );

  // --- Action items ---
  @POST("/api/actions")
  Future<ActionItem> createAction(@Body() ActionItem action);

  @GET("/api/actions/user/{mobile}")
  Future<List<ActionItem>> getActionsByUser(@Path("mobile") String mobile);

  @GET("/api/actions/visit/{visitId}")
  Future<List<ActionItem>> getActionsByVisit(@Path("visitId") String visitId);

  @PUT("/api/actions/{id}")
  Future<ActionItem> updateAction(
    @Path("id") String id,
    @Body() ActionItem action,
  );

  @GET("/api/actions/summary/{mobile}")
  Future<DashboardSummary> getDashboardSummary(@Path("mobile") String mobile);
}
