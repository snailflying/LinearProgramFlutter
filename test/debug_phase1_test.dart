import 'package:demo_flutter/linear_programming/linear_programming.dart';

/// 调试第一阶段求解
void main() {
  // 简单最小化问题
  // min z = x + 2y
  // 约束: x + y >= 3
  // x >= 0, y >= 0
  // 最优解应该是: x = 3, y = 0, z = 3
  
  final problem = LinearProgram(
    optimizationType: OptimizationType.minimize,
    objectiveCoefficients: [1.0, 2.0],
    constraintMatrix: [
      [1.0, 1.0],
    ],
    constraintRhs: [3.0],
    constraintTypes: [
      ConstraintType.greaterThanOrEqual,
    ],
  );

  print('=== 测试用例：简单最小化问题 ===');
  print('目标函数: min z = x + 2y');
  print('约束: x + y >= 3');
  print('变量边界: x >= 0, y >= 0');
  print('');
  
  final result = SimplexSolver.solve(problem);
  
  print('状态: ${result.status}');
  print('是否最优: ${result.isOptimal}');
  print('最优值: ${result.optimalValue}');
  print('最优解: ${result.solution}');
  print('消息: ${result.message}');
}

