import 'package:dio/dio.dart';
import 'package:retrofit/retrofit.dart';
import 'package:policysquare/data/models/risk_assessment.dart';
import 'package:policysquare/data/models/rfq.dart';
import 'package:policysquare/data/models/claim_story.dart';
import 'package:policysquare/data/models/underwriting_tip.dart';
import 'package:policysquare/data/models/health_quote_request.dart';
import 'package:policysquare/data/models/health_quote_response.dart';
import 'package:policysquare/data/models/property_budget.dart';

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
}
