int compute(int a, int b, int c) {
  var score = 0;
  if (a > 0 && b > 0) {
    score += 1;
  } else if (a < 0 || b < 0) {
    score -= 1;
  }
  for (var i = 0; i < c; i++) {
    if (i % 2 == 0) {
      score += i;
    } else {
      score -= i;
    }
  }
  return score;
}
