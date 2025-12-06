/// YALPS 测试用例
/// 
/// 作者: LiuZhiQiang
/// 基于 YALPS 原始测试用例翻译

import 'package:flutter_test/flutter_test.dart';
import 'package:demo_flutter/yalps/yalps.dart';

void main() {
  group('YALPS 基本功能测试', () {
    test('Wood Shop Problem - 简单线性规划', () {
      final model = Model<String, String>(
        direction: OptimizationDirection.maximize,
        objective: 'profit',
        constraints: {
          'wood': Constraint(max: 300),
          'labor': Constraint(max: 110),
        },
        variables: {
          'table': {
            'wood': 30.0,
            'labor': 5.0,
            'profit': 6.0,
          },
          'chair': {
            'wood': 20.0,
            'labor': 10.0,
            'profit': 8.0,
          },
        },
      );

      final solution = solve(model, null);

      expect(solution.status, SolutionStatus.optimal);
      expect(solution.result, closeTo(96.0, 0.01));
      
      // 验证变量值
      final tableValue = solution.variables.firstWhere(
        (v) => v.$1 == 'table',
        orElse: () => ('', 0.0),
      );
      final chairValue = solution.variables.firstWhere(
        (v) => v.$1 == 'chair',
        orElse: () => ('', 0.0),
      );
      
      expect(tableValue.$2, closeTo(4.0, 0.01));
      expect(chairValue.$2, closeTo(9.0, 0.01));
    });

    test('Integer Wood Shop Problem - 整数规划', () {
      final model = Model<String, String>(
        direction: OptimizationDirection.maximize,
        objective: 'profit',
        constraints: {
          'space': Constraint(max: 205),
          'price': Constraint(max: 40000),
        },
        variables: {
          'press': {
            'space': 15.0,
            'price': 8000.0,
            'profit': 100.0,
          },
          'lathe': {
            'space': 30.0,
            'price': 4000.0,
            'profit': 150.0,
          },
          'drill': {
            'space': 14.0,
            'price': 4500.0,
            'profit': 80.0,
          },
        },
        integers: ['press', 'lathe', 'drill'],
      );

      final solution = solve(model, null);

      expect(solution.status, SolutionStatus.optimal);
      expect(solution.result, closeTo(1010.0, 0.01));
      
      // 验证变量值都是整数
      for (final variable in solution.variables) {
        expect(variable.$2, variable.$2.round().toDouble());
      }
    });

    test('约束辅助函数测试', () {
      final lessEqConstraint = lessEq(100);
      expect(lessEqConstraint.max, 100);
      expect(lessEqConstraint.min, null);
      expect(lessEqConstraint.equal, null);

      final greaterEqConstraint = greaterEq(50);
      expect(greaterEqConstraint.min, 50);
      expect(greaterEqConstraint.max, null);
      expect(greaterEqConstraint.equal, null);

      final equalConstraint = equalTo(75);
      expect(equalConstraint.equal, 75);
      expect(equalConstraint.min, null);
      expect(equalConstraint.max, null);

      final rangeConstraint = inRange(10, 20);
      expect(rangeConstraint.min, 10);
      expect(rangeConstraint.max, 20);
      expect(rangeConstraint.equal, null);
    });
  });
}

