import 'package:flutter_test/flutter_test.dart';
import 'package:demo_flutter/linear_programming/linear_programming.dart';

/// 调试单纯形法
void main() {
  test('简单最大化问题', () {
    // 最大化 z = x
    // 约束: x <= 1, x >= 0
    // 期望: x = 1, z = 1
    
    final problem = LinearProgram(
      optimizationType: OptimizationType.maximize,
      objectiveCoefficients: [1.0],
      constraintMatrix: [
        [1.0], // x <= 1
      ],
      constraintRhs: [1.0],
      constraintTypes: [
        ConstraintType.lessThanOrEqual,
      ],
    );
    
    final result = SimplexSolver.solve(problem);
    
    print('状态: ${result.status}');
    print('最优值: ${result.optimalValue}');
    print('最优解: ${result.solution}');
    
    expect(result.isOptimal, true);
    expect(result.optimalValue, closeTo(1.0, 0.1));
    expect(result.solution![0], closeTo(1.0, 0.1));
  });

  test('带等式约束的最大化', () {
    // 最大化 z = D
    // 约束: D = 90 * t, t <= 1, t >= 0
    // 期望: t = 1, D = 90
    
    final problem = LinearProgram(
      optimizationType: OptimizationType.maximize,
      objectiveCoefficients: [1.0, 0.0], // 最大化D
      constraintMatrix: [
        [1.0, -90.0], // D - 90*t = 0
        [0.0, 1.0],   // t <= 1
      ],
      constraintRhs: [0.0, 1.0],
      constraintTypes: [
        ConstraintType.equal,
        ConstraintType.lessThanOrEqual,
      ],
      upperBounds: [double.infinity, 1.0],
    );
    
    final result = SimplexSolver.solve(problem);
    
    print('状态: ${result.status}');
    print('最优值: ${result.optimalValue}');
    print('最优解: ${result.solution}');
    
    expect(result.isOptimal, true);
    expect(result.optimalValue, closeTo(90.0, 0.1));
    if (result.solution != null) {
      expect(result.solution![1], closeTo(1.0, 0.1)); // t = 1
      expect(result.solution![0], closeTo(90.0, 0.1)); // D = 90
    }
  });
}

