import 'package:techdebt_sherpa/src/services/report_diff_service.dart';
import 'package:test/test.dart';

void main() {
  test('computes deltas and worsened files from json maps', () {
    final ReportDiffService service = ReportDiffService();
    final Map<String, Object?> left = <String, Object?>{
      'global_scores': <String, Object?>{
        'debt': 10,
        'risk': 20,
        'evolvability': 90
      },
      'files': <Object?>[
        <String, Object?>{
          'metrics': <String, Object?>{'path': 'lib/a.dart'},
          'scores': <String, Object?>{'debt': 20},
        },
      ],
    };
    final Map<String, Object?> right = <String, Object?>{
      'global_scores': <String, Object?>{
        'debt': 15,
        'risk': 18,
        'evolvability': 85
      },
      'files': <Object?>[
        <String, Object?>{
          'metrics': <String, Object?>{'path': 'lib/a.dart'},
          'scores': <String, Object?>{'debt': 25},
        },
      ],
    };

    final Map<String, Object?> delta = service.fromJsonMaps(left, right);

    expect(delta['debt_delta'], 5);
    expect(delta['risk_delta'], -2);
    expect(delta['evolvability_delta'], -5);
    final List<dynamic> worsened = delta['top_worsened'] as List<dynamic>;
    final Map<dynamic, dynamic> first = worsened.first as Map<dynamic, dynamic>;
    expect(first['path'], 'lib/a.dart');
    expect(first['debt_delta'], 5);
  });
}
