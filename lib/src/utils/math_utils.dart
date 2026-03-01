import 'dart:math';

double percentile(List<num> input, double p) {
  if (input.isEmpty) {
    return 0;
  }
  final List<double> sorted = input.map((num e) => e.toDouble()).toList()
    ..sort();
  final double rank = (p.clamp(0, 1) as double) * (sorted.length - 1);
  final int low = rank.floor();
  final int high = rank.ceil();
  if (low == high) {
    return sorted[low];
  }
  final double weight = rank - low;
  return sorted[low] * (1 - weight) + sorted[high] * weight;
}

double clamp01(double value) => value < 0 ? 0 : (value > 1 ? 1 : value);

double clamp100(double value) => value < 0 ? 0 : (value > 100 ? 100 : value);

double median(List<double> values) {
  if (values.isEmpty) {
    return 0;
  }
  final List<double> sorted = List<double>.from(values)..sort();
  final int mid = sorted.length ~/ 2;
  if (sorted.length.isEven) {
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }
  return sorted[mid];
}

double mad(List<double> values, double med) {
  if (values.isEmpty) {
    return 0;
  }
  final List<double> deviations =
      values.map((double v) => (v - med).abs()).toList();
  return median(deviations);
}

double safeLog2(int value) {
  if (value <= 0) {
    return 0;
  }
  return log(value) / ln2;
}
