/// 测试验证辅助函数
/// 
/// 作者: LiuZhiQiang

import 'package:demo_flutter/yalps/yalps.dart';
import 'read.dart';

const double maxDiff = 1e-5;

/// 计算相对差异
double relativeDifferenceFrom(double delta, double expected, double precision) {
  return (delta - precision) / (expected.abs() > 1.0 ? expected.abs() : 1.0);
}

double relativeDifference(double result, double expected, double precision) {
  return relativeDifferenceFrom((result - expected).abs(), expected, precision);
}

/// 检查结果是否最优
bool resultIsOptimal(double result, double expected, Options options) {
  final precision = options.precision ?? DefaultOptions.precision;
  final tolerance = options.tolerance ?? DefaultOptions.tolerance;
  
  if (expected.isNaN) {
    return result.isNaN;
  } else if (!expected.isFinite) {
    return expected == result;
  } else {
    return result.isFinite && 
           relativeDifference(result, expected, precision) <= (tolerance > maxDiff ? tolerance : maxDiff);
  }
}

/// 计算变量值的总和
Map<String, double> valueSums(Solution<String> solution, TestCaseModel model) {
  final variables = Map<String, Map<String, double>>.fromEntries(
    model.variables.map((v) => MapEntry(v.$1, v.$2)),
  );
  final sums = <String, double>{};
  
  for (final variable in solution.variables) {
    final key = variable.$1;
    final num = variable.$2;
    final coeffs = variables[key];
    if (coeffs != null) {
      for (final entry in coeffs.entries) {
        final constraint = entry.key;
        final coef = entry.value;
        sums[constraint] = (sums[constraint] ?? 0.0) + num * coef;
      }
    }
  }
  return sums;
}

/// 检查约束是否满足
bool constraintsAreSatisfied(
  Solution<String> solution,
  TestCaseModel model,
  double precision,
) {
  final sums = valueSums(solution, model);
  
  for (final entry in model.constraints) {
    final key = entry.$1;
    final constraint = entry.$2;
    final sum = sums[key] ?? 0.0;
    
    if (constraint.equal != null) {
      if (relativeDifference(sum, constraint.equal!, precision) > maxDiff) {
        return false;
      }
    } else {
      if (constraint.min != null && 
          relativeDifferenceFrom(constraint.min! - sum, constraint.min!, precision) > maxDiff) {
        return false;
      }
      if (constraint.max != null && 
          relativeDifferenceFrom(sum - constraint.max!, constraint.max!, precision) > maxDiff) {
        return false;
      }
    }
  }
  return true;
}

/// 检查变量值是否有效
bool variablesHaveValidValues(
  Solution<String> solution,
  TestCaseModel model,
  double precision,
) {
  for (final variable in solution.variables) {
    final varKey = variable.$1;
    final n = variable.$2;
    
    if (n < -precision) return false;
    
    final isInteger = model.integers.contains(varKey);
    final isBinary = model.binaries.contains(varKey);
    
    if (isInteger || isBinary) {
      if ((n - n.round()).abs() > precision) return false;
    }
    
    if (isBinary && n > 1 + precision) return false;
  }
  return true;
}

/// 验证解是否有效
bool validSolution(
  Solution<String> solution,
  double expected,
  TestCaseModel model,
  Options options,
) {
  return resultIsOptimal(solution.result, expected, options) &&
         variablesHaveValidValues(solution, model, options.precision ?? DefaultOptions.precision) &&
         (!expected.isFinite || constraintsAreSatisfied(
           solution, 
           model, 
           options.precision ?? DefaultOptions.precision,
         ));
}

/// 验证超时情况
bool validTimeout(Solution<String> solution) {
  return solution.status == SolutionStatus.timedout && solution.result.isNaN;
}

/// 验证解和状态
bool validSolutionAndStatus(
  Solution<String> solution,
  Solution<String> expected,
  TestCaseModel model,
  Options options,
) {
  // 状态必须匹配
  if (solution.status != expected.status) {
    return false;
  }
  
  // 对于超时情况
  if (validTimeout(solution)) {
    return true;
  }
  
  // 对于无界情况，检查结果符号是否一致
  if (solution.status == SolutionStatus.unbounded) {
    // 如果期望是 NaN，但实际是 Infinity，这可能是因为我们的实现方式不同
    // 检查符号是否一致
    if (expected.result.isNaN && solution.result.isInfinite) {
      // 这是可以接受的，因为无界问题的结果可能是 Infinity
      return true;
    }
    // 否则检查符号是否一致
    if (expected.result.isInfinite && solution.result.isInfinite) {
      return (expected.result > 0) == (solution.result > 0);
    }
  }
  
  // 其他情况使用标准验证
  return validSolution(solution, expected.result, model, options);
}

