import 'package:result_dart/result_dart.dart';

import '../models/pokemon_info.dart';

abstract interface class InfoService {
  Future<Result<PokemonInfo>> infoFor(String pokemonName);
}
