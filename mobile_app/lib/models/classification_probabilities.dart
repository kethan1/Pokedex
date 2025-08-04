class ClassificationProbabilities {
  final Map<String, double> _probabilities;

  ClassificationProbabilities(this._probabilities);

  factory ClassificationProbabilities.fromMap(Map<String, double> probabilities) {
    return ClassificationProbabilities(probabilities);
  }

  factory ClassificationProbabilities.fromLists(List<String> classes, List<double> probabilities) {
    if (classes.length != probabilities.length) {
      throw ArgumentError('Classes and probabilities must have the same length');
    }

    return ClassificationProbabilities(
      Map.fromIterables(classes, probabilities),
    );
  }

  double getProbability(String className) {
    return _probabilities[className] ?? 0.0;
  }

  List<String> getClasses() {
    return _probabilities.keys.toList();
  }

  List<double> getProbabilities() {
    return _probabilities.values.toList();
  }

  Map<String, double> getProbabilitiesMap() {
    return Map.from(_probabilities);
  }

  String getMostProbableClass() {
    return _probabilities.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  @override
  String toString() {
    return _probabilities.toString();
  }
}
