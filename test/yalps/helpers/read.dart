/// 测试用例读取函数
/// 
/// 作者: LiuZhiQiang

import 'dart:convert';
import 'dart:io';
import 'package:demo_flutter/yalps/yalps.dart';
import 'util.dart';

/// 测试用例模型
class TestCaseModel {
  final int hash;
  final OptimizationDirection? direction;
  final String? objective;
  final List<(String, Constraint)> constraints;
  final List<(String, Map<String, double>)> variables;
  final Set<String> integers;
  final Set<String> binaries;

  TestCaseModel({
    required this.hash,
    this.direction,
    this.objective,
    required this.constraints,
    required this.variables,
    required this.integers,
    required this.binaries,
  });
}

/// 测试用例
class TestCase {
  final String name;
  final TestCaseModel model;
  final Options options;
  final Solution<String> expected;

  TestCase({
    required this.name,
    required this.model,
    required this.options,
    required this.expected,
  });
}

/// JSON 测试用例类型
class JsonTestCase {
  final Map<String, dynamic> model;
  final Map<String, dynamic>? options;
  final Map<String, dynamic> expected;

  JsonTestCase({
    required this.model,
    this.options,
    required this.expected,
  });

  factory JsonTestCase.fromJson(Map<String, dynamic> json) {
    return JsonTestCase(
      model: json['model'] as Map<String, dynamic>,
      options: json['options'] as Map<String, dynamic>?,
      expected: json['expected'] as Map<String, dynamic>,
    );
  }
}

/// 读取测试用例
TestCase readCase(String name) {
  final file = File('test/cases/$name.json');
  final content = file.readAsStringSync();
  final json = jsonDecode(content) as Map<String, dynamic>;
  final data = JsonTestCase.fromJson(json);

  // 哈希测试用例名称作为随机种子
  final hash = hashString(name);
  
  // 转换约束
  final constraints = <(String, Constraint)>[];
  final constraintsMap = data.model['constraints'] as Map<String, dynamic>;
  for (final entry in constraintsMap.entries) {
    final constraintMap = entry.value as Map<String, dynamic>;
    constraints.add((
      entry.key,
      Constraint(
        equal: _toDoubleOrNull(constraintMap['equal']),
        min: _toDoubleOrNull(constraintMap['min']),
        max: _toDoubleOrNull(constraintMap['max']),
      ),
    ));
  }

  // 转换变量
  final variables = <(String, Map<String, double>)>[];
  final variablesMap = data.model['variables'] as Map<String, dynamic>;
  for (final entry in variablesMap.entries) {
    final coeffsMap = entry.value as Map<String, dynamic>;
    final coeffs = <String, double>{};
    for (final coeffEntry in coeffsMap.entries) {
      coeffs[coeffEntry.key] = _toDouble(coeffEntry.value);
    }
    variables.add((entry.key, coeffs));
  }

  // 转换整数和二进制变量
  final integers = <String>{};
  if (data.model['integers'] != null) {
    final ints = data.model['integers'] as List;
    integers.addAll(ints.cast<String>());
  }

  final binaries = <String>{};
  if (data.model['binaries'] != null) {
    final bins = data.model['binaries'] as List;
    binaries.addAll(bins.cast<String>());
  }

  // 创建模型
  final model = TestCaseModel(
    hash: hash,
    direction: data.model['direction'] == 'minimize'
        ? OptimizationDirection.minimize
        : OptimizationDirection.maximize,
    objective: data.model['objective'] as String?,
    constraints: constraints,
    variables: variables,
    integers: integers,
    binaries: binaries,
  );

  // 转换选项
  final options = Options(
    precision: _toDoubleOrNull(data.options?['precision']),
    checkCycles: data.options?['checkCycles'] as bool?,
    maxPivots: data.options?['maxPivots'] as int?,
    tolerance: _toDoubleOrNull(data.options?['tolerance']),
    timeout: _toDoubleOrNull(data.options?['timeout']),
    maxIterations: data.options?['maxIterations'] as int?,
    includeZeroVariables: data.options?['includeZeroVariables'] as bool?,
  );

  // 转换期望结果
  final expectedStatus = _parseStatus(data.expected['status'] as String);
  final expectedResult = _parseResult(
    data.expected['result'],
    data.model['direction'] == 'minimize',
  );
  
  final expectedVariables = <(String, double)>[];
  if (data.expected['variables'] != null) {
    final varsMap = data.expected['variables'] as Map<String, dynamic>;
    for (final entry in varsMap.entries) {
      expectedVariables.add((entry.key, _toDouble(entry.value)));
    }
  }

  final expected = Solution(
    status: expectedStatus,
    result: expectedResult,
    variables: expectedVariables,
  );

  return TestCase(
    name: name,
    model: model,
    options: options,
    expected: expected,
  );
}

/// 解析状态
SolutionStatus _parseStatus(String status) {
  switch (status) {
    case 'optimal':
      return SolutionStatus.optimal;
    case 'infeasible':
      return SolutionStatus.infeasible;
    case 'unbounded':
      return SolutionStatus.unbounded;
    case 'timedout':
      return SolutionStatus.timedout;
    case 'cycled':
      return SolutionStatus.cycled;
    default:
      return SolutionStatus.optimal;
  }
}

/// 转换为 double
double _toDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is num) return value.toDouble();
  throw ArgumentError('Cannot convert $value to double');
}

/// 转换为 double 或 null
double? _toDoubleOrNull(dynamic value) {
  if (value == null) return null;
  return _toDouble(value);
}

/// 解析结果
double _parseResult(dynamic result, bool isMinimize) {
  if (result == null) return double.nan;
  if (result == 'Infinity' || result == double.infinity) {
    return isMinimize ? double.negativeInfinity : double.infinity;
  }
  if (result == '-Infinity' || result == double.negativeInfinity) {
    return isMinimize ? double.infinity : double.negativeInfinity;
  }
  return _toDouble(result);
}

/// 读取所有测试用例
List<TestCase> readAllCases([List<String>? caseNames]) {
  final cases = caseNames ?? _getAllCaseNames();
  return cases.map((name) => readCase(name)).toList();
}

/// 获取所有测试用例名称
List<String> _getAllCaseNames() {
  final dir = Directory('test/cases');
  return dir
      .listSync()
      .whereType<File>()
      .map((f) => f.path.split('/').last.replaceAll('.json', ''))
      .toList()
    ..sort();
}

/// 大型测试用例（跳过以加快测试速度）
const List<String> largeCases = [
  'Monster 2',
  'Monster Problem',
  'Vendor Selection',
];

/// 获取小型测试用例
List<String> getSmallCases() {
  final all = _getAllCaseNames();
  return all.where((name) => !largeCases.contains(name)).toList();
}

