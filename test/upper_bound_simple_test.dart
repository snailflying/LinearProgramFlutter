import 'package:flutter_test/flutter_test.dart';
import 'package:demo_flutter/linear_programming/linear_programming.dart';

/// 简化的上界约束测试用例
void main() {
  test('最简单的上界测试：max x, x <= 5', () {
    // 变量：x
    // 目标：max x
    // 约束：x <= 5（通过 upperBounds）
    // 期望解：x = 5
    
    final problem = LinearProgram(
      optimizationType: OptimizationType.maximize,
      objectiveCoefficients: [1.0],
      constraintMatrix: [],
      constraintRhs: [],
      constraintTypes: [],
      upperBounds: [5.0],
    );
    
    final result = SimplexSolver.solve(problem);
    print('状态: ${result.status}');
    print('最优值: ${result.optimalValue}');
    print('最优解: ${result.solution}');
    
    expect(result.isOptimal, true);
    expect(result.optimalValue, closeTo(5.0, 0.1));
    if (result.solution != null) {
      expect(result.solution![0], closeTo(5.0, 0.1));
    }
  });

  test('简单的上界测试：max x + y, x <= 10, y <= 5', () {
    // 变量：[x, y]
    // 目标：max x + y
    // 约束：无
    // 上界：[10.0, 5.0]（x <= 10, y <= 5）
    // 期望：x = 10, y = 5，最优值 = 15
    
    final problem = LinearProgram(
      optimizationType: OptimizationType.maximize,
      objectiveCoefficients: [1.0, 1.0],
      constraintMatrix: [],
      constraintRhs: [],
      constraintTypes: [],
      upperBounds: [10.0, 5.0],
    );
    
    final result = SimplexSolver.solve(problem);
    print('状态: ${result.status}');
    print('最优值: ${result.optimalValue}');
    print('最优解: ${result.solution}');
    
    expect(result.isOptimal, true);
    expect(result.optimalValue, closeTo(15.0, 0.1));
    if (result.solution != null) {
      expect(result.solution![0], closeTo(10.0, 0.1));
      expect(result.solution![1], closeTo(5.0, 0.1));
    }
  });

  test('带下界的上界测试：max x, x >= 1, x <= 10', () {
    // 变量：x
    // 目标：max x
    // 下界：[1.0]（x >= 1）
    // 上界：[10.0]（x <= 10）
    // 期望：x = 10，最优值 = 10
    
    final problem = LinearProgram(
      optimizationType: OptimizationType.maximize,
      objectiveCoefficients: [1.0],
      constraintMatrix: [],
      constraintRhs: [],
      constraintTypes: [],
      lowerBounds: [1.0],
      upperBounds: [10.0],
    );
    
    final result = SimplexSolver.solve(problem);
    print('状态: ${result.status}');
    print('最优值: ${result.optimalValue}');
    print('最优解: ${result.solution}');
    
    expect(result.isOptimal, true);
    expect(result.optimalValue, closeTo(10.0, 0.1));
    if (result.solution != null) {
      expect(result.solution![0], greaterThanOrEqualTo(0.99));
      expect(result.solution![0], lessThanOrEqualTo(10.01));
    }
  });
}

