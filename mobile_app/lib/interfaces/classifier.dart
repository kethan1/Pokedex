import 'package:result_dart/result_dart.dart';
import '../models/classification_probabilities.dart';

abstract interface class Classifier<I> {
  Future<Result<ClassificationProbabilities>> classify(I input);
  Future<void> close();
}
