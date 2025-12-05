import 'package:flutter_test/flutter_test.dart';
import 'package:demo_flutter/linear_programming/linear_programming.dart';

/// 简化的营销活动测试
void main() {
  test('简单满额立减测试', () {
    // 1个订单，1个活动：满400减90
    // 订单金额：420元（满足门槛）
    // 期望：t=1, D=90

    // 变量：[y, A, D, t]
    // y: 订单是否参加活动 (0或1)
    // A: 活动总金额
    // D: 优惠金额
    // t: 触发次数 (0或1)

    // 重新设计约束，使用更简单直接的方式
    // 变量：[y, A, D, t]
    // y: 订单是否参加活动 (0或1)
    // A: 活动总金额
    // D: 优惠金额
    // t: 触发次数 (0或1)

    // 约束：
    // 1. A = 420 * y  (如果参加，金额为420)
    // 2. A >= 400 * t  (只有金额>=400时才能触发)
    // 3. D = 90 * t    (触发时优惠90)
    // 4. y <= 1        (y是0或1)
    // 5. t <= 1        (t是0或1，通过upperBounds设置)
    // 6. t <= y        (只有参加活动才能触发)
    // 7. 添加非负约束（通过lowerBounds，默认为0）

    // 注意：目标函数是最大化D，而D = 90*t
    // 如果y=0，则A=0，约束A>=400*t要求t=0，所以D=0
    // 如果y=1，则A=420，约束A>=400*t允许t=1，所以D=90
    // 因此最优解应该是y=1, t=1, A=420, D=90

    final problem = LinearProgram(
      optimizationType: OptimizationType.maximize,
      objectiveCoefficients: [0.0, 0.0, 1.0, 0.0], // 最大化D
      constraintMatrix: [
        // A = 420 * y => A - 420*y = 0
        [0.0, 1.0, 0.0, -420.0],
        // A >= 400 * t => A - 400*t >= 0
        [0.0, 1.0, 0.0, -400.0],
        // D = 90 * t => D - 90*t = 0
        [0.0, 0.0, 1.0, -90.0],
        // y <= 1
        [1.0, 0.0, 0.0, 0.0],
        // t <= y => y - t >= 0
        [1.0, 0.0, 0.0, -1.0],
      ],
      constraintRhs: [0.0, 0.0, 0.0, 1.0, 0.0],
      constraintTypes: [
        ConstraintType.equal,
        ConstraintType.greaterThanOrEqual,
        ConstraintType.equal,
        ConstraintType.lessThanOrEqual,
        ConstraintType.greaterThanOrEqual,
      ],
      integerVariables: {0, 3}, // y和t是整数
      upperBounds: [
        1.0,
        double.infinity,
        double.infinity,
        1.0,
      ], // y <= 1, t <= 1
    );

    // 先测试连续松弛问题
    print('=== 测试连续松弛问题 ===');
    final relaxedProblem = LinearProgram(
      optimizationType: problem.optimizationType,
      objectiveCoefficients: problem.objectiveCoefficients,
      constraintMatrix: problem.constraintMatrix,
      constraintRhs: problem.constraintRhs,
      constraintTypes: problem.constraintTypes,
      lowerBounds: problem.lowerBounds,
      upperBounds: problem.upperBounds,
      integerVariables: {}, // 移除整数约束
    );

    final relaxedResult = SimplexSolver.solve(relaxedProblem);
    print('松弛问题状态: ${relaxedResult.status}');
    print('松弛问题最优值: ${relaxedResult.optimalValue}');
    print('松弛问题最优解: ${relaxedResult.solution}');

    // 再测试整数规划
    print('\n=== 测试整数规划问题 ===');
    final result = IntegerSolver.solve(problem);

    print('状态: ${result.status}');
    print('最优值: ${result.optimalValue}');
    print('最优解: ${result.solution}');

    expect(result.isOptimal, true);
    if (result.isOptimal && result.solution != null) {
      // y应该为1，t应该为1，D应该为90
      expect(result.solution![0], 1.0); // y = 1
      expect(result.solution![3], 1.0); // t = 1
      expect(result.optimalValue, closeTo(90.0, 0.1));
    }
  });
}
