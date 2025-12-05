import 'package:flutter_test/flutter_test.dart';
import 'package:demo_flutter/linear_programming/linear_programming.dart';

void main() {
  test('上界约束测试', () {
    // 测试上界约束
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
    expect(result.solution![0], lessThanOrEqualTo(5.01));
  });

  test('带约束的上界测试', () {
    // 变量：[y, A, C, D, t]
    // 目标：max D
    // 约束：
    // y <= 1
    // A = 420 * y
    // C = 3 * y
    // A >= 400 * t
    // D = 90 * t
    // 上界：t <= 1
    // 期望：y=1, A=420, C=3, t=1, D=90
    
    final problem = LinearProgram(
      optimizationType: OptimizationType.maximize,
      objectiveCoefficients: [0.0, 0.0, 0.0, 1.0, 0.0],
      constraintMatrix: [
        [1.0, 0.0, 0.0, 0.0, 0.0], // y <= 1
        [-420.0, 1.0, 0.0, 0.0, 0.0], // A = 420*y
        [-3.0, 0.0, 1.0, 0.0, 0.0], // C = 3*y
        [0.0, 1.0, 0.0, 0.0, -400.0], // A >= 400*t
        [0.0, 0.0, 0.0, 1.0, -90.0], // D = 90*t
      ],
      constraintRhs: [1.0, 0.0, 0.0, 0.0, 0.0],
      constraintTypes: [
        ConstraintType.lessThanOrEqual,
        ConstraintType.equal,
        ConstraintType.equal,
        ConstraintType.greaterThanOrEqual,
        ConstraintType.equal,
      ],
      upperBounds: [double.infinity, double.infinity, double.infinity, double.infinity, 1.0],
    );
    
    final result = SimplexSolver.solve(problem);
    print('状态: ${result.status}');
    print('最优值: ${result.optimalValue}');
    print('最优解: ${result.solution}');
    
    expect(result.isOptimal, true);
    if (result.solution != null) {
      final t = result.solution![4];
      print('t = $t');
      expect(t, lessThanOrEqualTo(1.01), reason: 't 应该 <= 1（上界）');
    }
  });

  test('简化下界上界测试', () {
    // 最简化的测试：
    // 变量：[x, y]
    // 约束：无
    // 下界：[1.0, 0.0]（x >= 1）
    // 上界：[10.0, 5.0]（x <= 10, y <= 5）
    // 目标：max x + y
    // 期望：x = 10, y = 5，最优值 = 15
    
    final problem = LinearProgram(
      optimizationType: OptimizationType.maximize,
      objectiveCoefficients: [1.0, 1.0],
      constraintMatrix: [],
      constraintRhs: [],
      constraintTypes: [],
      lowerBounds: [1.0, 0.0], // x >= 1
      upperBounds: [10.0, 5.0], // x <= 10, y <= 5
    );
    
    final result = SimplexSolver.solve(problem);
    print('状态: ${result.status}');
    print('最优值: ${result.optimalValue}');
    print('最优解: ${result.solution}');
    
    expect(result.isOptimal, true);
    expect(result.optimalValue, closeTo(15.0, 0.1));
    if (result.solution != null) {
      expect(result.solution![0], greaterThanOrEqualTo(0.99), reason: 'x 应该 >= 1');
      expect(result.solution![0], lessThanOrEqualTo(10.01), reason: 'x 应该 <= 10');
      expect(result.solution![1], lessThanOrEqualTo(5.01), reason: 'y 应该 <= 5');
    }
  });

  test('带下界的上界测试', () {
    // 模拟分支定界的节点2场景
    // 变量：[y, A, C, D, t]
    // 目标：max D
    // 下界：[1.0, 0.0, 0.0, 0.0, 0.0]（y >= 1）
    // 上界：[Infinity, Infinity, Infinity, Infinity, 1.0]（t <= 1）
    
    final problem = LinearProgram(
      optimizationType: OptimizationType.maximize,
      objectiveCoefficients: [0.0, 0.0, 0.0, 1.0, 0.0],
      constraintMatrix: [
        [1.0, 0.0, 0.0, 0.0, 0.0], // y <= 1
        [-420.0, 1.0, 0.0, 0.0, 0.0], // A = 420*y
        [-3.0, 0.0, 1.0, 0.0, 0.0], // C = 3*y
        [0.0, 1.0, 0.0, 0.0, -400.0], // A >= 400*t
        [0.0, 0.0, 0.0, 1.0, -90.0], // D = 90*t
      ],
      constraintRhs: [1.0, 0.0, 0.0, 0.0, 0.0],
      constraintTypes: [
        ConstraintType.lessThanOrEqual,
        ConstraintType.equal,
        ConstraintType.equal,
        ConstraintType.greaterThanOrEqual,
        ConstraintType.equal,
      ],
      lowerBounds: [1.0, 0.0, 0.0, 0.0, 0.0], // y >= 1
      upperBounds: [double.infinity, double.infinity, double.infinity, double.infinity, 1.0],
    );
    
    final result = SimplexSolver.solve(problem);
    print('状态: ${result.status}');
    print('最优值: ${result.optimalValue}');
    print('最优解: ${result.solution}');
    
    expect(result.isOptimal, true);
    if (result.solution != null) {
      final y = result.solution![0];
      final t = result.solution![4];
      print('y = $y, t = $t');
      expect(y, greaterThanOrEqualTo(0.99), reason: 'y 应该 >= 1（下界）');
      expect(t, lessThanOrEqualTo(1.01), reason: 't 应该 <= 1（上界）');
    }
  });
}

