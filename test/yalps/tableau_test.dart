/// 单纯形表测试
/// 
/// 作者: LiuZhiQiang
/// 基于 YALPS tableau.test.ts 翻译

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:demo_flutter/yalps/yalps.dart';
import 'package:demo_flutter/yalps/tableau.dart' as tableau_lib;
import 'helpers/read.dart';
import 'helpers/util.dart';

void main() {
  group('单纯形表测试', () {
    final testData = getSmallCases().map((name) {
      final testCase = readCase(name);
      return testCase.model;
    }).toList();

    // deepEquals 使用 Object.is (sameValue 算法) 而不是 sameValueZero 算法，所以 deepEquals(0, -0) === false
    double negate(double x) => (x == 0.0 ? 0.0 : -x);

    test('空模型', () {
      final result = tableau_lib.tableauModel<String, String>(
        Model<String, String>(
          constraints: {},
          variables: {},
        ),
      );
      final expected = tableau_lib.TableauModel<String, String>(
        tableau: tableau_lib.Tableau(
          matrix: Float64List(1),
          width: 1,
          height: 1,
          positionOfVariable: Int32List.fromList([0, 1]),
          variableAtPosition: Int32List.fromList([0, 1]),
        ),
        sign: 1.0,
        variables: [],
        integers: [],
      );
      expectTableauModelEqual(result, expected);
    });

    // 辅助函数：从模型创建单纯形表
    tableau_lib.TableauModel<String, String> tableauFromModelWith(
      TestCaseModel model,
      String key,
      dynamic value,
    ) {
      final constraints = Map<String, Constraint>.fromEntries(
        model.constraints.map((c) => MapEntry(c.$1, c.$2)),
      );
      final variables = Map<String, Map<String, double>>.fromEntries(
        model.variables.map((v) => MapEntry(v.$1, v.$2)),
      );

      switch (key) {
        case 'direction':
          return tableau_lib.tableauModel<String, String>(
            Model<String, String>(
              direction: value as OptimizationDirection?,
              objective: model.objective,
              constraints: constraints,
              variables: variables,
              integers: model.integers.isEmpty ? null : model.integers.toList(),
              binaries: model.binaries.isEmpty ? null : model.binaries.toList(),
            ),
          );
        case 'objective':
          return tableau_lib.tableauModel<String, String>(
            Model<String, String>(
              direction: model.direction,
              objective: value as String?,
              constraints: constraints,
              variables: variables,
              integers: model.integers.isEmpty ? null : model.integers.toList(),
              binaries: model.binaries.isEmpty ? null : model.binaries.toList(),
            ),
          );
        case 'constraints':
          return tableau_lib.tableauModel<String, String>(
            Model<String, String>(
              direction: model.direction,
              objective: model.objective,
              constraints: value as Map<String, Constraint>,
              variables: variables,
              integers: model.integers.isEmpty ? null : model.integers.toList(),
              binaries: model.binaries.isEmpty ? null : model.binaries.toList(),
            ),
          );
        case 'variables':
          return tableau_lib.tableauModel<String, String>(
            Model<String, String>(
              direction: model.direction,
              objective: model.objective,
              constraints: constraints,
              variables: value as Map<String, Map<String, double>>,
              integers: model.integers.isEmpty ? null : model.integers.toList(),
              binaries: model.binaries.isEmpty ? null : model.binaries.toList(),
            ),
          );
        case 'integers':
          return tableau_lib.tableauModel<String, String>(
            Model<String, String>(
              direction: model.direction,
              objective: model.objective,
              constraints: constraints,
              variables: variables,
              integers: value,
              binaries: model.binaries.isEmpty ? null : model.binaries.toList(),
            ),
          );
        case 'binaries':
          return tableau_lib.tableauModel<String, String>(
            Model<String, String>(
              direction: model.direction,
              objective: model.objective,
              constraints: constraints,
              variables: variables,
              integers: model.integers.isEmpty ? null : model.integers.toList(),
              binaries: value,
            ),
          );
        default:
          throw ArgumentError('Unknown key: $key');
      }
    }

    // 计算约束的行数
    int numRows(Constraint constraint) {
      if (constraint.equal != null) return 2;
      return (constraint.max != null ? 1 : 0) + (constraint.min != null ? 1 : 0);
    }

    // 计算约束的行索引
    int rowOfConstraint(List<(String, Constraint)> constraints, int index) {
      int sum = 1;
      for (int i = 0; i < index; i++) {
        sum += numRows(constraints[i].$2);
      }
      return sum;
    }

    for (final model in testData) {
      test('目标行为零（如果没有给出目标）- ${model.hash}', () {
        final result = tableauFromModelWith(model, 'objective', null);
        final expected = tableau_lib.tableauModel<String, String>(
          Model<String, String>(
            direction: model.direction,
            objective: model.objective,
            constraints: Map<String, Constraint>.fromEntries(
              model.constraints.map((c) => MapEntry(c.$1, c.$2)),
            ),
            variables: Map<String, Map<String, double>>.fromEntries(
              model.variables.map((v) => MapEntry(v.$1, v.$2)),
            ),
            integers: model.integers.isEmpty ? null : model.integers.toList(),
            binaries: model.binaries.isEmpty ? null : model.binaries.toList(),
          ),
        );
        // 将目标行填充为 0
        for (int c = 0; c < expected.tableau.width; c++) {
          expected.tableau.matrix[c] = 0.0;
        }
        expectTableauModelEqual(result, expected);
      });

      test('目标行和符号对相反优化方向取反 - ${model.hash}', () {
        final direction = model.direction == OptimizationDirection.minimize
            ? OptimizationDirection.maximize
            : OptimizationDirection.minimize;
        final result = tableauFromModelWith(model, 'direction', direction);

        final expected = tableau_lib.tableauModel<String, String>(
          Model<String, String>(
            direction: model.direction,
            objective: model.objective,
            constraints: Map<String, Constraint>.fromEntries(
              model.constraints.map((c) => MapEntry(c.$1, c.$2)),
            ),
            variables: Map<String, Map<String, double>>.fromEntries(
              model.variables.map((v) => MapEntry(v.$1, v.$2)),
            ),
            integers: model.integers.isEmpty ? null : model.integers.toList(),
            binaries: model.binaries.isEmpty ? null : model.binaries.toList(),
          ),
        );
        for (int c = 0; c < expected.tableau.width; c++) {
          expected.tableau.matrix[c] = negate(expected.tableau.matrix[c]);
        }
        final expectedWithNegatedSign = tableau_lib.TableauModel<String, String>(
          tableau: expected.tableau,
          sign: -expected.sign,
          variables: expected.variables,
          integers: expected.integers,
        );
        expectTableauModelEqual(result, expectedWithNegatedSign);
      });

      test('约束作为对象、数组和 Map - ${model.hash}', () {
        final constraintsMap = Map<String, Constraint>.fromEntries(
          model.constraints.map((c) => MapEntry(c.$1, c.$2)),
        );
        final map = tableauFromModelWith(model, 'constraints', constraintsMap);
        final array = tableau_lib.tableauModel<String, String>(
          Model<String, String>(
            direction: model.direction,
            objective: model.objective,
            constraints: constraintsMap,
            variables: Map<String, Map<String, double>>.fromEntries(
              model.variables.map((v) => MapEntry(v.$1, v.$2)),
            ),
            integers: model.integers.isEmpty ? null : model.integers.toList(),
            binaries: model.binaries.isEmpty ? null : model.binaries.toList(),
          ),
        );
        expectTableauModelEqual(map, array);
      });

      test('变量作为对象、数组和 Map - ${model.hash}', () {
        final variablesMap = Map<String, Map<String, double>>.fromEntries(
          model.variables.map((v) => MapEntry(v.$1, v.$2)),
        );
        final map = tableauFromModelWith(model, 'variables', variablesMap);
        final array = tableau_lib.tableauModel<String, String>(
          Model<String, String>(
            direction: model.direction,
            objective: model.objective,
            constraints: Map<String, Constraint>.fromEntries(
              model.constraints.map((c) => MapEntry(c.$1, c.$2)),
            ),
            variables: variablesMap,
            integers: model.integers.isEmpty ? null : model.integers.toList(),
            binaries: model.binaries.isEmpty ? null : model.binaries.toList(),
          ),
        );
        expectTableauModelEqual(map, array);
      });

      test('没有变量标记为整数 - ${model.hash}', () {
        final boolNone = tableauFromModelWith(model, 'integers', false);
        final setNone = tableauFromModelWith(model, 'integers', <String>{});
        final iterNone = tableauFromModelWith(model, 'integers', <String>[]);
        expectTableauModelEqual(boolNone, setNone);
        expectTableauModelEqual(iterNone, setNone);
      });

      test('所有变量标记为整数 - ${model.hash}', () {
        final varKeys = getKeys(model.variables);
        final boolAll = tableauFromModelWith(model, 'integers', true);
        final setAll = tableauFromModelWith(model, 'integers', varKeys.toSet());
        final iterAll = tableauFromModelWith(model, 'integers', varKeys);
        expectTableauModelEqual(boolAll, setAll);
        expectTableauModelEqual(iterAll, setAll);
      });

      test('整数作为 Set 和数组 - ${model.hash}', () {
        final rand = newRand(model.hash);
        final varSample = sample(rand, getKeys(model.variables));
        final setSample = tableauFromModelWith(model, 'integers', varSample.toSet());
        final iterSample = tableauFromModelWith(model, 'integers', varSample);
        expectTableauModelEqual(iterSample, setSample);
      });

      test('没有变量标记为二进制 - ${model.hash}', () {
        final boolNone = tableauFromModelWith(model, 'binaries', false);
        final setNone = tableauFromModelWith(model, 'binaries', <String>{});
        final iterNone = tableauFromModelWith(model, 'binaries', <String>[]);
        expectTableauModelEqual(boolNone, setNone);
        expectTableauModelEqual(iterNone, setNone);
      });

      test('所有变量标记为二进制 - ${model.hash}', () {
        final varKeys = getKeys(model.variables);
        final boolTrue = tableauFromModelWith(model, 'binaries', true);
        final setAll = tableauFromModelWith(model, 'binaries', varKeys.toSet());
        final iterAll = tableauFromModelWith(model, 'binaries', varKeys);
        expectTableauModelEqual(boolTrue, setAll);
        expectTableauModelEqual(iterAll, setAll);
      });

      test('二进制作为 Set 和数组 - ${model.hash}', () {
        final rand = newRand(model.hash);
        final varSample = sample(rand, getKeys(model.variables));
        final set = tableauFromModelWith(model, 'binaries', varSample.toSet());
        final iter = tableauFromModelWith(model, 'binaries', varSample);
        expectTableauModelEqual(iter, set);
      });

      test('二进制优先级高于整数 - ${model.hash}', () {
        final rand = newRand(model.hash);
        final key = randomElement(rand, model.variables).$1;
        final result = tableau_lib.tableauModel<String, String>(
          Model<String, String>(
            direction: model.direction,
            objective: model.objective,
            constraints: Map<String, Constraint>.fromEntries(
              model.constraints.map((c) => MapEntry(c.$1, c.$2)),
            ),
            variables: Map<String, Map<String, double>>.fromEntries(
              model.variables.map((v) => MapEntry(v.$1, v.$2)),
            ),
            integers: [key],
            binaries: [key],
          ),
        );
        final expected = tableau_lib.tableauModel<String, String>(
          Model<String, String>(
            direction: model.direction,
            objective: model.objective,
            constraints: Map<String, Constraint>.fromEntries(
              model.constraints.map((c) => MapEntry(c.$1, c.$2)),
            ),
            variables: Map<String, Map<String, double>>.fromEntries(
              model.variables.map((v) => MapEntry(v.$1, v.$2)),
            ),
            integers: [],
            binaries: [key],
          ),
        );
        expectTableauModelEqual(result, expected);
      });
    }
  });
}

/// 比较两个 TableauModel 是否相等
void expectTableauModelEqual(
  tableau_lib.TableauModel<String, String> a,
  tableau_lib.TableauModel<String, String> b,
) {
  expect(a.sign, b.sign, reason: 'Sign mismatch');
  expect(a.integers, b.integers, reason: 'Integers mismatch');
  expect(a.variables.length, b.variables.length, reason: 'Variables length mismatch');
  
  for (int i = 0; i < a.variables.length; i++) {
    expect(a.variables[i].key, b.variables[i].key, reason: 'Variable key mismatch at index $i');
  }

  expect(a.tableau.width, b.tableau.width, reason: 'Tableau width mismatch');
  expect(a.tableau.height, b.tableau.height, reason: 'Tableau height mismatch');
  
  for (int i = 0; i < a.tableau.matrix.length; i++) {
    expect(
      a.tableau.matrix[i],
      closeTo(b.tableau.matrix[i], 1e-10),
      reason: 'Matrix mismatch at index $i',
    );
  }

  for (int i = 0; i < a.tableau.positionOfVariable.length; i++) {
    expect(
      a.tableau.positionOfVariable[i],
      b.tableau.positionOfVariable[i],
      reason: 'positionOfVariable mismatch at index $i',
    );
  }

  for (int i = 0; i < a.tableau.variableAtPosition.length; i++) {
    expect(
      a.tableau.variableAtPosition[i],
      b.tableau.variableAtPosition[i],
      reason: 'variableAtPosition mismatch at index $i',
    );
  }
}

