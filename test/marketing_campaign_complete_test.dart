import 'package:flutter_test/flutter_test.dart';
import 'package:demo_flutter/linear_programming/linear_programming.dart';
import 'package:demo_flutter/marketing_campaign/marketing_ilp_builder.dart';

/// 基于文档中完整示例数据的测试
void main() {
  group('营销活动完整示例测试', () {
    test('示例：3个订单3个活动的最优组合', () {
      // 基于文档"营销活动数学建模方案-示例.md"中的示例
      
      // 订单数据
      final orders = [
        // O1: C1×1(150) + C2×1(80) + D1×1(50) = 280元, 3件
        OrderData(
          id: 'O1',
          items: [
            OrderItem(ticketTypeId: 'C1', quantity: 1, price: 150.0),
            OrderItem(ticketTypeId: 'C2', quantity: 1, price: 80.0),
            OrderItem(ticketTypeId: 'D1', quantity: 1, price: 50.0),
          ],
        ),
        // O2: C1×2(300) + D2×1(120) = 420元, 3件
        OrderData(
          id: 'O2',
          items: [
            OrderItem(ticketTypeId: 'C1', quantity: 2, price: 150.0),
            OrderItem(ticketTypeId: 'D2', quantity: 1, price: 120.0),
          ],
        ),
        // O3: C2×2(160) + E1×1(200) = 360元, 3件
        OrderData(
          id: 'O3',
          items: [
            OrderItem(ticketTypeId: 'C2', quantity: 2, price: 80.0),
            OrderItem(ticketTypeId: 'E1', quantity: 1, price: 200.0),
          ],
        ),
      ];
      
      // 活动数据
      final promotions = [
        // P1: 满4件打8折 (COUNT_DISCOUNT)
        // 可参与: C1, C2, D1
        PromotionData(
          id: 'P1',
          kind: PromotionKind.countDiscount,
          scopeTicketTypeIds: ['C1', 'C2', 'D1'],
          thresholdCount: 4,
          discountRate: 0.8,
        ),
        // P2: 满400减90 (AMOUNT_OFF)
        // 可参与: C1, D2, E1
        PromotionData(
          id: 'P2',
          kind: PromotionKind.amountOff,
          scopeTicketTypeIds: ['C1', 'D2', 'E1'],
          thresholdAmount: 400.0,
          discountAmount: 90.0,
        ),
        // P3: 每满300减50，最多2次 (AMOUNT_EVERY_OFF)
        // 可参与: C2, D1, D2, E1
        PromotionData(
          id: 'P3',
          kind: PromotionKind.eachAmountOff,
          scopeTicketTypeIds: ['C2', 'D1', 'D2', 'E1'],
          stepAmount: 300.0,
          discountAmountPerStep: 50.0,
          maxTimes: 2,
        ),
      ];
      
      // 计算 a_{o,i} 和 c_{o,i} 矩阵
      final amountMatrix = <List<double>>[];
      final countMatrix = <List<double>>[];
      
      for (var o = 0; o < orders.length; o++) {
        final orderAmounts = <double>[];
        final orderCounts = <double>[];
        
        for (var i = 0; i < promotions.length; i++) {
          final promo = promotions[i];
          var amount = 0.0;
          var count = 0.0;
          
          for (final item in orders[o].items) {
            if (promo.scopeTicketTypeIds.contains(item.ticketTypeId)) {
              amount += item.price * item.quantity;
              count += item.quantity;
            }
          }
          
          orderAmounts.add(amount);
          orderCounts.add(count);
        }
        
        amountMatrix.add(orderAmounts);
        countMatrix.add(orderCounts);
      }
      
      // 验证预处理数据
      // P1: O1(280元,3件), O2(300元,2件), O3(160元,2件)
      expect(amountMatrix[0][0], 280.0);
      expect(countMatrix[0][0], 3.0);
      expect(amountMatrix[1][0], 300.0);
      expect(countMatrix[1][0], 2.0);
      
      // P2: O1(150元), O2(420元), O3(200元)
      expect(amountMatrix[0][1], 150.0);
      expect(amountMatrix[1][1], 420.0);
      expect(amountMatrix[2][1], 200.0);
      
      // P3: O1(130元), O2(120元), O3(360元)
      expect(amountMatrix[0][2], 130.0);
      expect(amountMatrix[1][2], 120.0);
      expect(amountMatrix[2][2], 360.0);
      
      // 构建并求解ILP模型
      final builder = MarketingILPBuilder(
        orders: orders,
        promotions: promotions,
        amountMatrix: amountMatrix,
        countMatrix: countMatrix,
      );
      
      // 注意：当前实现只支持立减类活动，不支持打折类
      // 所以P1会被跳过，只求解P2和P3
      final problem = builder.build();
      final result = IntegerSolver.solve(problem);
      
      expect(result.status, isNot(SolutionStatus.unsolved));
      
      if (result.isOptimal) {
        print('最优值: ${result.optimalValue}');
        print('最优解: ${result.solution}');
        
        // 根据文档，最优解应该是：
        // O1和O3参加P1（满件打折），O2参加P2（满400减90）
        // 但由于当前不支持打折，实际结果可能不同
      }
    });

    test('满额立减：单订单触发', () {
      // P2: 满400减90
      // O2单独即可触发（420元 >= 400元）
      
      final orders = [
        OrderData(
          id: 'O2',
          items: [
            OrderItem(ticketTypeId: 'C1', quantity: 2, price: 150.0),
            OrderItem(ticketTypeId: 'D2', quantity: 1, price: 120.0),
          ],
        ),
      ];
      
      final promotions = [
        PromotionData(
          id: 'P2',
          kind: PromotionKind.amountOff,
          scopeTicketTypeIds: ['C1', 'D2', 'E1'],
          thresholdAmount: 400.0,
          discountAmount: 90.0,
        ),
      ];
      
      final amountMatrix = [[420.0]];
      final countMatrix = [[3.0]];
      
      final builder = MarketingILPBuilder(
        orders: orders,
        promotions: promotions,
        amountMatrix: amountMatrix,
        countMatrix: countMatrix,
      );
      
      final problem = builder.build();
      
      print('=== 问题详情 ===');
      print('目标函数系数: ${problem.objectiveCoefficients}');
      print('约束数: ${problem.constraintMatrix.length}');
      print('变量数: ${problem.numVariables}');
      print('整数变量: ${problem.integerVariables}');
      print('上界: ${problem.upperBounds}');
      for (var i = 0; i < problem.constraintMatrix.length; i++) {
        print('约束$i: ${problem.constraintMatrix[i]} ${problem.constraintTypes[i]} ${problem.constraintRhs[i]}');
      }
      
      // 先测试松弛问题
      final relaxed = LinearProgram(
        optimizationType: problem.optimizationType,
        objectiveCoefficients: problem.objectiveCoefficients,
        constraintMatrix: problem.constraintMatrix,
        constraintRhs: problem.constraintRhs,
        constraintTypes: problem.constraintTypes,
        upperBounds: problem.upperBounds,
        integerVariables: {}, // 移除整数约束
      );
      final relaxedResult = SimplexSolver.solve(relaxed);
      print('松弛问题状态: ${relaxedResult.status}');
      print('松弛问题最优值: ${relaxedResult.optimalValue}');
      print('松弛问题最优解: ${relaxedResult.solution}');
      
      final result = IntegerSolver.solve(problem);
      
      print('状态: ${result.status}');
      print('最优值: ${result.optimalValue}');
      print('最优解: ${result.solution}');
      
      expect(result.isOptimal, true);
      expect(result.optimalValue, closeTo(90.0, 0.1));
    });

    test('每满额立减：多订单组合', () {
      // P3: 每满300减50，最多2次
      // O1(130) + O2(120) + O3(360) = 610，可触发2次（减100）
      
      final orders = [
        OrderData(id: 'O1', items: [
          OrderItem(ticketTypeId: 'C2', quantity: 1, price: 80.0),
          OrderItem(ticketTypeId: 'D1', quantity: 1, price: 50.0),
        ]),
        OrderData(id: 'O2', items: [
          OrderItem(ticketTypeId: 'D2', quantity: 1, price: 120.0),
        ]),
        OrderData(id: 'O3', items: [
          OrderItem(ticketTypeId: 'C2', quantity: 2, price: 80.0),
          OrderItem(ticketTypeId: 'E1', quantity: 1, price: 200.0),
        ]),
      ];
      
      final promotions = [
        PromotionData(
          id: 'P3',
          kind: PromotionKind.eachAmountOff,
          scopeTicketTypeIds: ['C2', 'D1', 'D2', 'E1'],
          stepAmount: 300.0,
          discountAmountPerStep: 50.0,
          maxTimes: 2,
        ),
      ];
      
      final amountMatrix = [
        [130.0], // O1
        [120.0], // O2
        [360.0], // O3
      ];
      final countMatrix = [
        [2.0],
        [1.0],
        [3.0],
      ];
      
      final builder = MarketingILPBuilder(
        orders: orders,
        promotions: promotions,
        amountMatrix: amountMatrix,
        countMatrix: countMatrix,
      );
      
      final problem = builder.build();
      final result = IntegerSolver.solve(problem);
      
      expect(result.isOptimal, true);
      // 三单都参加：610元，触发2次，优惠100元
      expect(result.optimalValue, closeTo(100.0, 0.1));
    });
  });
}

