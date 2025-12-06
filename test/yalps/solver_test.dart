/// 求解器测试
/// 
/// 作者: LiuZhiQiang
/// 基于 YALPS solver.test.ts 翻译

import 'package:flutter_test/flutter_test.dart';
import 'package:demo_flutter/yalps/yalps.dart';
import 'helpers/read.dart';
import 'helpers/validate.dart';
import 'helpers/util.dart';

void main() {
  group('求解器测试', () {
    // 读取测试用例并求解
    final testCases = getSmallCases().map((name) {
      final testCase = readCase(name);
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
      final solution = solve(model, testCase.options);
      return (
        testCase: testCase,
        model: model,
        solution: solution,
      );
    }).toList();

    test('验证测试用例的解', () {
      for (final data in testCases) {
        final isValid = validSolutionAndStatus(
          data.solution,
          data.testCase.expected,
          data.testCase.model,
          data.testCase.options,
        );
        expect(isValid, true,
            reason: 'Test case "${data.testCase.name}" failed');
      }
    });

    test('变量顺序在解中保持（零变量不包含）', () {
      for (final data in testCases) {
        // 即，solution.variables 应该是 data.variables 的子序列
        int i = 0;
        for (final variable in data.solution.variables) {
          final key = variable.$1;
          bool found = false;
          while (!found && i < data.testCase.model.variables.length) {
            found = key == data.testCase.model.variables[i].$1;
            i++;
          }
          expect(found, true,
              reason: 'Variable order not preserved in ${data.testCase.name}');
        }
      }
    });

    test('变量顺序在解中保持（零变量包含）', () {
      for (final data in testCases) {
        if (data.testCase.expected.status != SolutionStatus.optimal) {
          continue; // 模型不适用
        }
        final options = Options(
          precision: data.testCase.options.precision,
          checkCycles: data.testCase.options.checkCycles,
          maxPivots: data.testCase.options.maxPivots,
          tolerance: data.testCase.options.tolerance,
          timeout: data.testCase.options.timeout,
          maxIterations: data.testCase.options.maxIterations,
          includeZeroVariables: true,
        );
        final solution = solve(data.model, options);
        final solutionKeys = solution.variables.map((v) => v.$1).toList();
        final modelKeys = data.testCase.model.variables.map((v) => v.$1).toList();
        expect(solutionKeys, modelKeys,
            reason: 'Variable order not preserved with zero variables in ${data.testCase.name}');
        
        final isValid = validSolutionAndStatus(
          solution,
          data.testCase.expected,
          data.testCase.model,
          options,
        );
        expect(isValid, true);
      }
    });

    test('移除未使用的变量给出最优解', () {
      for (final data in testCases) {
        if (data.solution.status != SolutionStatus.optimal ||
            data.testCase.model.variables.length == data.solution.variables.length) {
          continue; // 模型不适用
        }

        final variables = <(String, Map<String, double>)>[];
        int i = 0;
        for (final variable in data.testCase.model.variables) {
          // 假设没有重复的键
          if (i < data.solution.variables.length &&
              variable.$1 == data.solution.variables[i].$1) {
            // 使用的变量，在解中出现
            variables.add(variable);
            i++;
          }
        }

        final removedModel = Model<String, String>(
          direction: data.model.direction,
          objective: data.model.objective,
          constraints: data.model.constraints,
          variables: Map<String, Map<String, double>>.fromEntries(
            variables.map((v) => MapEntry(v.$1, v.$2)),
          ),
          integers: data.model.integers,
          binaries: data.model.binaries,
        );
        final removed = solve(removedModel, data.testCase.options);
        final isValid = validSolutionAndStatus(
          removed,
          data.testCase.expected,
          data.testCase.model,
          data.testCase.options,
        );
        expect(isValid, true,
            reason: 'Removing unused variables failed in ${data.testCase.name}');
      }
    });

    test('复制非二进制变量给出最优解', () {
      for (final data in testCases) {
        final nonBinaryVariables = data.testCase.model.variables
            .where((v) => !data.testCase.model.binaries.contains(v.$1))
            .toList();
        if (nonBinaryVariables.isEmpty) {
          continue; // 模型不适用
        }

        final rand = newRand(data.testCase.model.hash);
        final variables = List<(String, Map<String, double>)>.from(nonBinaryVariables);
        variables.add(randomElement(rand, data.testCase.model.variables));

        final duplicateModel = Model<String, String>(
          direction: data.model.direction,
          objective: data.model.objective,
          constraints: data.model.constraints,
          variables: Map<String, Map<String, double>>.fromEntries(
            variables.map((v) => MapEntry(v.$1, v.$2)),
          ),
          integers: data.model.integers,
          binaries: data.model.binaries,
        );
        final duplicate = solve(duplicateModel, data.testCase.options);
        final isValid = validSolutionAndStatus(
          duplicate,
          data.testCase.expected,
          data.testCase.model,
          data.testCase.options,
        );
        expect(isValid, true,
            reason: 'Duplicating non-binary variable failed in ${data.testCase.name}');
      }
    });

    test('更严格的约束（不与最优解冲突）', () {
      for (final data in testCases) {
        // 模型不适用，constraintSums 不反映实际/最优解
        final tolerance = data.testCase.options.tolerance ?? DefaultOptions.tolerance;
        if (tolerance != 0.0 || data.solution.status != SolutionStatus.cycled) {
          continue;
        }

        final rand = newRand(data.testCase.model.hash);
        final lowerOrUpper = data.testCase.model.constraints
            .where((entry) {
              final constraint = entry.$2;
              return constraint.equal == null && constraint.min != constraint.max;
            })
            .toList();
        if (lowerOrUpper.isEmpty) {
          continue; // 模型不适用
        }

        final sums = valueSums(data.solution, data.testCase.model);
        final hasSlack = lowerOrUpper
            .map((entry) {
              final key = entry.$1;
              final constraint = entry.$2;
              final sum = sums[key] ?? 0.0;
              final lowerSlack = sum - (constraint.min ?? double.negativeInfinity);
              final upperSlack = (constraint.max ?? double.infinity) - sum;
              return (
                key: key,
                constraint: constraint,
                lowerSlack: lowerSlack,
                upperSlack: upperSlack,
              );
            })
            .where((x) => x.lowerSlack > 0.0 || x.upperSlack > 0.0)
            .toList();
        if (hasSlack.isEmpty) {
          continue; // 没有存在松弛的约束
        }

        final selected = randomElement(rand, hasSlack);
        final min = selected.constraint.min == null
            ? double.negativeInfinity
            : selected.constraint.min! + selected.lowerSlack;
        final max = selected.constraint.max == null
            ? double.infinity
            : selected.constraint.max! - selected.upperSlack;
        final constraints = List<(String, Constraint)>.from(data.testCase.model.constraints);
        constraints.add((selected.key, Constraint(min: min, max: max)));

        final newModel = Model<String, String>(
          direction: data.model.direction,
          objective: data.model.objective,
          constraints: Map<String, Constraint>.fromEntries(
            constraints.map((c) => MapEntry(c.$1, c.$2)),
          ),
          variables: data.model.variables,
          integers: data.model.integers,
          binaries: data.model.binaries,
        );
        final restricted = solve(newModel, data.testCase.options);
        final isValid = validSolutionAndStatus(
          restricted,
          data.testCase.expected,
          data.testCase.model,
          data.testCase.options,
        );
        expect(isValid, true,
            reason: 'More restrictive constraint failed in ${data.testCase.name}');
      }
    });

    test('容差选项给出容差范围内的结果', () {
      for (final data in testCases) {
        if (data.testCase.model.integers.length + data.testCase.model.binaries.length == 0) {
          continue; // 模型不适用
        }

        final rand = newRand(data.testCase.model.hash);
        final tol = data.testCase.options.tolerance ?? DefaultOptions.tolerance;
        final tolerance = rand() * (1.0 - tol) + tol;
        final options = Options(
          precision: data.testCase.options.precision,
          checkCycles: data.testCase.options.checkCycles,
          maxPivots: data.testCase.options.maxPivots,
          tolerance: tolerance,
          timeout: data.testCase.options.timeout,
          maxIterations: data.testCase.options.maxIterations,
          includeZeroVariables: data.testCase.options.includeZeroVariables,
        );
        final solution = solve(data.model, options);
        final isValid = validSolutionAndStatus(
          solution,
          data.testCase.expected,
          data.testCase.model,
          options,
        );
        expect(isValid, true,
            reason: 'Tolerance option failed in ${data.testCase.name}');
      }
    });

    test('超时正确发生', () {
      for (final data in testCases) {
        final n = data.testCase.model.integers.length;
        if (n == 0) {
          continue; // 模型不适用
        }

        final timeout = n < 50 ? 0.0 : n / 25.0;
        final options = Options(
          precision: data.testCase.options.precision,
          checkCycles: data.testCase.options.checkCycles,
          maxPivots: data.testCase.options.maxPivots,
          tolerance: data.testCase.options.tolerance,
          timeout: timeout,
          maxIterations: data.testCase.options.maxIterations,
          includeZeroVariables: data.testCase.options.includeZeroVariables,
        );
        final expected = Solution(
          status: SolutionStatus.timedout,
          result: data.testCase.expected.result,
          variables: data.testCase.expected.variables,
        );
        final solution = solve(data.model, options);
        final isValid = validSolutionAndStatus(
          solution,
          expected,
          data.testCase.model,
          options,
        );
        expect(isValid, true,
            reason: 'Timeout failed in ${data.testCase.name}');
      }
    });
  });
}

