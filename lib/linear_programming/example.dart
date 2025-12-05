import 'linear_programming.dart';

/// 线性规划求解器使用示例
void main() {
  print('=== 线性规划求解器示例 ===\n');

  // 示例1：简单的线性规划问题（最大化）
  example1();

  // 示例2：带等式约束的线性规划问题
  example2();

  // 示例3：带变量边界的线性规划问题
  example3();

  // 示例4：整数线性规划问题
  example4();
}

/// 示例1：最大化问题
/// 
/// 最大化: z = 3x + 2y
/// 约束:
///   x + y <= 4
///   2x + y <= 6
///   x >= 0, y >= 0
void example1() {
  print('示例1：最大化问题');
  print('目标函数: max z = 3x + 2y');
  print('约束条件:');
  print('  x + y <= 4');
  print('  2x + y <= 6');
  print('  x >= 0, y >= 0\n');

  final problem = LinearProgram(
    optimizationType: OptimizationType.maximize,
    objectiveCoefficients: [3.0, 2.0],
    constraintMatrix: [
      [1.0, 1.0],  // x + y <= 4
      [2.0, 1.0],  // 2x + y <= 6
    ],
    constraintRhs: [4.0, 6.0],
    constraintTypes: [
      ConstraintType.lessThanOrEqual,
      ConstraintType.lessThanOrEqual,
    ],
  );

  final result = SimplexSolver.solve(problem);
  printResult(result);
  print('');
}

/// 示例2：带等式约束的问题
/// 
/// 最小化: z = x + 2y
/// 约束:
///   x + y = 3
///   x <= 2
///   y <= 2
///   x >= 0, y >= 0
void example2() {
  print('示例2：带等式约束的问题');
  print('目标函数: min z = x + 2y');
  print('约束条件:');
  print('  x + y = 3');
  print('  x <= 2');
  print('  y <= 2');
  print('  x >= 0, y >= 0\n');

  final problem = LinearProgram(
    optimizationType: OptimizationType.minimize,
    objectiveCoefficients: [1.0, 2.0],
    constraintMatrix: [
      [1.0, 1.0],  // x + y = 3
      [1.0, 0.0],  // x <= 2
      [0.0, 1.0],  // y <= 2
    ],
    constraintRhs: [3.0, 2.0, 2.0],
    constraintTypes: [
      ConstraintType.equal,
      ConstraintType.lessThanOrEqual,
      ConstraintType.lessThanOrEqual,
    ],
  );

  final result = SimplexSolver.solve(problem);
  printResult(result);
  print('');
}

/// 示例3：带变量边界的问题
/// 
/// 最大化: z = 2x + 3y
/// 约束:
///   x + y <= 5
///   0 <= x <= 3
///   1 <= y <= 4
void example3() {
  print('示例3：带变量边界的问题');
  print('目标函数: max z = 2x + 3y');
  print('约束条件:');
  print('  x + y <= 5');
  print('  0 <= x <= 3');
  print('  1 <= y <= 4\n');

  final problem = LinearProgram(
    optimizationType: OptimizationType.maximize,
    objectiveCoefficients: [2.0, 3.0],
    constraintMatrix: [
      [1.0, 1.0],  // x + y <= 5
    ],
    constraintRhs: [5.0],
    constraintTypes: [
      ConstraintType.lessThanOrEqual,
    ],
    lowerBounds: [0.0, 1.0],
    upperBounds: [3.0, 4.0],
  );

  final result = SimplexSolver.solve(problem);
  printResult(result);
  print('');
}

/// 示例4：整数线性规划问题
/// 
/// 最大化: z = 5x + 8y
/// 约束:
///   x + y <= 6
///   5x + 9y <= 45
///   x >= 0, y >= 0
///   x, y 为整数
void example4() {
  print('示例4：整数线性规划问题');
  print('目标函数: max z = 5x + 8y');
  print('约束条件:');
  print('  x + y <= 6');
  print('  5x + 9y <= 45');
  print('  x >= 0, y >= 0');
  print('  x, y 为整数\n');

  final problem = LinearProgram(
    optimizationType: OptimizationType.maximize,
    objectiveCoefficients: [5.0, 8.0],
    constraintMatrix: [
      [1.0, 1.0],   // x + y <= 6
      [5.0, 9.0],   // 5x + 9y <= 45
    ],
    constraintRhs: [6.0, 45.0],
    constraintTypes: [
      ConstraintType.lessThanOrEqual,
      ConstraintType.lessThanOrEqual,
    ],
    integerVariables: {0, 1}, // x 和 y 都是整数
  );

  final result = IntegerSolver.solve(problem);
  printResult(result);
  print('');
}

/// 打印求解结果
void printResult(LinearProgramResult result) {
  print('求解结果:');
  print('  状态: ${result.status}');
  print('  消息: ${result.message}');
  
  if (result.isOptimal) {
    print('  最优值: ${result.optimalValue?.toStringAsFixed(4)}');
    if (result.solution != null) {
      print('  最优解:');
      for (var i = 0; i < result.solution!.length; i++) {
        print('    x${i + 1} = ${result.solution![i].toStringAsFixed(4)}');
      }
    }
  }
}

