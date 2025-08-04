import 'dart:math';

List<double> softmax(List<double> logits) {
  double sumExp = logits.map((logit) => exp(logit)).reduce((a, b) => a + b);
  return logits.map((logit) => exp(logit) / sumExp).toList();
}
