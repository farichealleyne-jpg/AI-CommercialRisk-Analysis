import 'package:google_generative_ai/google_generative_ai.dart';

void main() async {
  const apiKey = String.fromEnvironment('GEMINI_API_KEY');
  final model = GenerativeModel(
    model: 'gemini-pro-latest',
    apiKey: apiKey,
    generationConfig: GenerationConfig(responseMimeType: 'application/json'),
  );

  final rawData = {
    'housekeeping':
        'Stocks are stored beneath electrical fittings/close to electrical installation/Plant walls.',
  };

  const prompt = '''
You are an expert Risk Engineer compiling a 'Risk Recommendations Report'.
I am providing you a JSON object containing raw answers to a factory inspection questionnaire. These answers are often short 'Yes', 'No', or a dropdown selection (like 'Poor', 'Good', etc.).

Your task is to rewrite these raw answers into a professional, descriptive sentence or short paragraph suitable for an official PDF report.
If the answer implies a positive safety measure (e.g. 'Yes' for Fire Training), you can say 'Yes' or briefly elaborate on it.
If the answer is a dropdown value (e.g. Housekeeping = 'Poor'), explain what that means in a warehouse/factory context professionally.

DO NOT output anything other than a valid JSON object. Do not use Markdown block ```json. Just raw valid JSON.
The JSON keys must match the input keys EXACTLY so I can map them back.

Here is the raw data:
\${jsonEncode(rawData)}

Ensure the output is valid JSON mapped exactly like the input keys.
''';

  try {
    print("Calling Gemini...");
    final response = await model.generateContent([Content.text(prompt)]);
    final resultText = response.text;
    print("Result: \$resultText");
  } catch (e) {
    print('THIS IS THE GEMINI ERROR: $e');
  }
}
