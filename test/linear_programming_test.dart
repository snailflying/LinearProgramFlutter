import 'package:flutter_test/flutter_test.dart';
import 'package:demo_flutter/linear_programming/linear_programming.dart';

void main() {
  group('线性规划求解器测试', () {
    test('简单最大化问题', () {
      final problem = LinearProgram(
        optimizationType: OptimizationType.maximize,
        objectiveCoefficients: [3.0, 2.0],
        constraintMatrix: [
          [1.0, 1.0],
          [2.0, 1.0],
        ],
        constraintRhs: [4.0, 6.0],
        constraintTypes: [
          ConstraintType.lessThanOrEqual,
          ConstraintType.lessThanOrEqual,
        ],
      );

      final result = SimplexSolver.solve(problem);
      
      expect(result.isOptimal, true);
      expect(result.optimalValue, closeTo(10.0, 0.01));
      expect(result.solution, isNotNull);
      expect(result.solution!.length, 2);
    });

    test('简单最小化问题', () {
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

      final result = SimplexSolver.solve(problem);
      
      expect(result.isOptimal, true);
      expect(result.solution, isNotNull);
    });

    test('带等式约束的问题', () {
      final problem = LinearProgram(
        optimizationType: OptimizationType.minimize,
        objectiveCoefficients: [1.0, 2.0],
        constraintMatrix: [
          [1.0, 1.0],
          [1.0, 0.0],
        ],
        constraintRhs: [3.0, 2.0],
        constraintTypes: [
          ConstraintType.equal,
          ConstraintType.lessThanOrEqual,
        ],
      );

      final result = SimplexSolver.solve(problem);
      
      expect(result.status, isNot(SolutionStatus.unsolved));
    });

    test('带变量边界的问题', () {
      final problem = LinearProgram(
        optimizationType: OptimizationType.maximize,
        objectiveCoefficients: [2.0, 3.0],
        constraintMatrix: [
          [1.0, 1.0],
        ],
        constraintRhs: [5.0],
        constraintTypes: [
          ConstraintType.lessThanOrEqual,
        ],
        lowerBounds: [0.0, 1.0],
        upperBounds: [3.0, 4.0],
      );

      final result = SimplexSolver.solve(problem);
      
      expect(result.status, isNot(SolutionStatus.unsolved));
    });

    test('整数规划问题', () {
      final problem = LinearProgram(
        optimizationType: OptimizationType.maximize,
        objectiveCoefficients: [5.0, 8.0],
        constraintMatrix: [
          [1.0, 1.0],
          [5.0, 9.0],
        ],
        constraintRhs: [6.0, 45.0],
        constraintTypes: [
          ConstraintType.lessThanOrEqual,
          ConstraintType.lessThanOrEqual,
        ],
        integerVariables: {0, 1},
      );

      final result = IntegerSolver.solve(problem);
      
      expect(result.status, isNot(SolutionStatus.unsolved));
      
      if (result.isOptimal && result.solution != null) {
        // 验证解是整数
        for (var i = 0; i < result.solution!.length; i++) {
          if (problem.integerVariables.contains(i)) {
            expect(result.solution![i], closeTo(result.solution![i].round(), 0.001));
          }
        }
      }
    });
  });
}

