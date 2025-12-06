/// YALPS 完整测试套件
/// 
/// 作者: LiuZhiQiang
/// 基于 YALPS 原始测试用例

import 'package:flutter_test/flutter_test.dart';
import 'package:demo_flutter/yalps/yalps.dart';
import 'helpers/read.dart';
import 'helpers/validate.dart';

void main() {
  group('YALPS 完整测试套件（小型测试用例）', () {
    // 读取所有小型测试用例（排除大型测试用例以加快测试速度）
    final testCases = readAllCases(getSmallCases());

    // 为每个测试用例创建测试
    for (final testCase in testCases) {
      test('${testCase.name}', () {
        // 构建模型
        final model = Model<String, String>(
          direction: testCase.model.direction,
          objective: testCase.model.objective,
          constraints: Map<String, Constraint>.fromEntries(
            testCase.model.constraints.map((c) => MapEntry(c.$1, c.$2)),
          ),
          variables: Map<String, Map<String, double>>.fromEntries(
            testCase.model.variables.map((v) => MapEntry(v.$1, v.$2)),
          ),
          integers: testCase.model.integers.isEmpty
              ? null
              : testCase.model.integers.toList(),
          binaries: testCase.model.binaries.isEmpty
              ? null
              : testCase.model.binaries.toList(),
        );

        // 求解
        final solution = solve(model, testCase.options);

        // 验证
        final isValid = validSolutionAndStatus(
          solution,
          testCase.expected,
          testCase.model,
          testCase.options,
        );

        expect(isValid, true, 
          reason: 'Test case "${testCase.name}" failed. '
                  'Expected status: ${testCase.expected.status}, '
                  'Got: ${solution.status}. '
                  'Expected result: ${testCase.expected.result}, '
                  'Got: ${solution.result}');
      });
    }
  });
}

