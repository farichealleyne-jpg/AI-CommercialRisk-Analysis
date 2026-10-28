import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:policysquare/config/api_keys.dart';
import 'package:policysquare/data/models/risk_assessment.dart';

class GeminiReportAnalyzer {

  static Future<Map<String, dynamic>> analyzeAssessment(
    RiskAssessment assessment,
  ) async {
    final rawData = jsonDecode(assessment.data ?? '{}') as Map<String, dynamic>;

    final model = GenerativeModel(
      model: 'gemini-pro-latest',
      apiKey: ApiKeys.gemini,
      generationConfig: GenerationConfig(responseMimeType: 'application/json'),
    );

    // We only want to analyze specific fields that need professional wording.
    // Things like 'insuredName', 'occupancyType', 'totalArea' etc. remain as is.
    final fieldsToAnalyze = {
      'housekeeping': rawData['housekeeping'],
      'fireTraining': rawData['fireTraining'],
      'maintenance': rawData['maintenance'],
      'hotWorkPermit': rawData['hotWorkPermit'],
      'combustibleMaterials': rawData['combustibleMaterials'],
      'flammableSolvents': rawData['flammableSolvents'],
      'smokeDetection': rawData['smokeDetection'],
      'cctv': rawData['cctv'],
      'securityTeam': rawData['securityTeam'],
    };

    final prompt =
        '''
You are an expert Risk Engineer compiling a 'Risk Recommendations Report'.
I am providing you a JSON object containing raw answers to a factory inspection questionnaire. These answers are often short 'Yes', 'No', or a dropdown selection (like 'Poor', 'Good', etc.).

Your task is to rewrite these raw answers into a professional, descriptive sentence or short paragraph suitable for an official PDF report.
If the answer implies a positive safety measure (e.g. 'Yes' for Fire Training), you can say 'Yes' or briefly elaborate on it.
If the answer is a dropdown value (e.g. Housekeeping = 'Poor'), explain what that means in a warehouse/factory context professionally.

DO NOT output anything other than a valid JSON object. Do not use Markdown block ```json. Just raw valid JSON.
The JSON keys must match the input keys EXACTLY so I can map them back.

Here is the raw data:
${jsonEncode(fieldsToAnalyze)}

Ensure the output is valid JSON mapped exactly like the input keys.
''';

    try {
      final response = await model.generateContent([Content.text(prompt)]);
      final resultText = response.text;

      if (resultText != null) {
        String cleanJson = resultText;
        final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(cleanJson);
        if (match != null) {
          cleanJson = match.group(0)!;
        }

        final Map<String, dynamic> generatedAnalysis = jsonDecode(cleanJson);

        // Merge the generated analysis back over the original data
        Map<String, dynamic> finalData = Map<String, dynamic>.from(rawData);
        generatedAnalysis.forEach((key, value) {
          if (finalData.containsKey(key)) {
            finalData[key] = value;
          }
        });

        // Now return the modified map!
        return finalData;
      }
    } catch (e) {
      print('Gemini API Error: \$e');
      // On error, fallback to raw data
    }

    return rawData;
  }
}
