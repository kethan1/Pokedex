import 'dart:async';
import 'dart:convert';

import 'package:fllama/fllama.dart';
import 'package:result_dart/result_dart.dart';

import '../interfaces/info_service.dart';
import '../models/pokemon_info.dart';

class PokemonInfoService implements InfoService {
  final String modelPath;

  PokemonInfoService({required this.modelPath});

  Future<String> _runChat(OpenAiRequest request) async {
    print('Running chat with model: $modelPath');
    final completer = Completer<String>();
    fllamaChat(request, (String resp, String json, bool done) {
      if (done) completer.complete(resp);
    });
    return await completer.future;
  }

  @override
  Future<Result<PokemonInfo>> infoFor(String name) async {
    if (name.isEmpty) {
      throw Failure(ArgumentError('Pokemon name cannot be empty'));
    }
    print('Generating info for Pokemon: $name');

    final prompt =
        '''Output EXACTLY a JSON object with three fields in the following format describing the Pokemon "$name":
{
  "description": "<short description>",
  "types": [...],
  "glowColor": "#RRGGBB"
}
Do not output any additional text.
''';

    final request = OpenAiRequest(
      modelPath: modelPath,
      maxTokens: 512,
      temperature: 0.1,
      topP: 1.0,
      presencePenalty: 1.1,
      logger: (log) {
        // ignore: avoid_print
        print('[llama.cpp] $log');
      },
      messages: [Message(Role.user, prompt)],
    );

    final jsonString = await _runChat(request);

    print('Received JSON response: $jsonString');

    try {
      final Map<String, dynamic> data = jsonDecode(
        jsonString.substring(
          jsonString.indexOf('{'),
          jsonString.lastIndexOf('}') + 1,
        ),
      );

      return Success(PokemonInfo.fromJson(data));
    } catch (e) {
      print('Error parsing JSON: $e');
      return Failure(Exception('LLM returned invalid JSON'));
    }
  }
}
