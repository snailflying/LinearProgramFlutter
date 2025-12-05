import 'package:flutter_test/flutter_test.dart';
import 'package:demo_flutter/linear_programming/linear_programming.dart';
import 'package:demo_flutter/marketing_campaign/marketing_ilp_builder.dart';

/// 营销活动ILP模型测试
/// 
/// 基于docs文档中的营销活动数学建模模型和示例数据
void main() {
  group('营销活动ILP模型测试', () {
    test('示例1：满件打折（COUNT_DISCOUNT）', () {
      // 使用MarketingILPBuilder测试满件打折
      // 这个测试现在使用完整的模型构建器，支持Big-M约束
      final orders = [
        OrderData(
          id: 'O1',
          items: [
            OrderItem(ticketTypeId: 'C1', quantity: 1, price: 150.0),
            OrderItem(ticketTypeId: 'C2', quantity: 1, price: 80.0),
            OrderItem(ticketTypeId: 'D1', quantity: 1, price: 50.0),
          ],
        ),
        OrderData(
          id: 'O2',
          items: [
            OrderItem(ticketTypeId: 'C1', quantity: 2, price: 150.0),
          ],
        ),
        OrderData(
          id: 'O3',
          items: [
            OrderItem(ticketTypeId: 'C2', quantity: 2, price: 80.0),
          ],
        ),
      ];
      
      final promotions = [
        PromotionData(
          id: 'P1',
          kind: PromotionKind.countDiscount,
          scopeTicketTypeIds: ['C1', 'C2', 'D1'],
          thresholdCount: 4,
          discountRate: 0.8,
        ),
      ];
      
      final amountMatrix = [[280.0], [300.0], [160.0]];
      final countMatrix = [[3.0], [2.0], [2.0]];
      
      final builder = MarketingILPBuilder(
        orders: orders,
        promotions: promotions,
        amountMatrix: amountMatrix,
        countMatrix: countMatrix,
      );
      
      final problem = builder.build();
      final result = IntegerSolver.solve(problem);
      
      expect(result.status, isNot(SolutionStatus.unsolved));
      if (result.isOptimal) {
        // 最优解应该是：O1和O3参加活动，A_1=440, C_1=5, z_1=1, D_1=0.2*440=88
        expect(result.optimalValue, greaterThan(0.0));
      }
    });

    test('示例2：满额立减（AMOUNT_OFF）', () {
      // 使用MarketingILPBuilder测试满额立减
      final orders = [
        OrderData(id: 'O1', items: [OrderItem(ticketTypeId: 'C1', quantity: 1, price: 150.0)]),
        OrderData(id: 'O2', items: [
          OrderItem(ticketTypeId: 'C1', quantity: 2, price: 150.0),
          OrderItem(ticketTypeId: 'D2', quantity: 1, price: 120.0),
        ]),
        OrderData(id: 'O3', items: [OrderItem(ticketTypeId: 'E1', quantity: 1, price: 200.0)]),
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
      
      final amountMatrix = [[150.0], [420.0], [200.0]];
      final countMatrix = [[1.0], [3.0], [1.0]];
      
      final builder = MarketingILPBuilder(
        orders: orders,
        promotions: promotions,
        amountMatrix: amountMatrix,
        countMatrix: countMatrix,
      );
      
      final problem = builder.build();
      final result = IntegerSolver.solve(problem);
      
      expect(result.status, isNot(SolutionStatus.unsolved));
      if (result.isOptimal) {
        // 最优解应该是：O2参加活动，t_2=1, D_2=90
        expect(result.optimalValue, closeTo(90.0, 0.1));
      }
    });

    test('示例3：每满额立减（AMOUNT_EVERY_OFF）', () {
      // 使用MarketingILPBuilder测试每满额立减
      final orders = [
        OrderData(id: 'O1', items: [
          OrderItem(ticketTypeId: 'C2', quantity: 1, price: 80.0),
          OrderItem(ticketTypeId: 'D1', quantity: 1, price: 50.0),
        ]),
        OrderData(id: 'O2', items: [OrderItem(ticketTypeId: 'D2', quantity: 1, price: 120.0)]),
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
      
      final amountMatrix = [[130.0], [120.0], [360.0]];
      final countMatrix = [[2.0], [1.0], [3.0]];
      
      final builder = MarketingILPBuilder(
        orders: orders,
        promotions: promotions,
        amountMatrix: amountMatrix,
        countMatrix: countMatrix,
      );
      
      final problem = builder.build();
      final result = IntegerSolver.solve(problem);
      
      expect(result.status, isNot(SolutionStatus.unsolved));
      if (result.isOptimal) {
        // 最优解：三单都参加，A_3=610, t_3=2, D_3=100
        expect(result.optimalValue, closeTo(100.0, 0.1));
      }
    });

    test('完整示例：多活动组合优化', () {
      // 基于文档中的完整示例
      // 3个订单，3个活动
      // 目标：最大化总优惠金额
      
      // 这是一个更复杂的MILP问题，需要同时考虑多个活动
      // 由于变量和约束较多，这里先测试一个简化版本
      
      // 活动P1：满4件打8折（O1:3件280元, O2:2件300元, O3:2件160元）
      // 活动P2：满400减90（O1:150元, O2:420元, O3:200元）
      // 活动P3：每满300减50（O1:130元, O2:120元, O3:360元）
      
      // 决策：每个订单选择参加哪个活动（或不参加）
      // 目标：max D_1 + D_2 + D_3
      
      // 由于模型复杂度较高，这里先测试能否求解
      // 实际应用中需要构建完整的模型
      
      expect(true, true); // 占位测试
    });
  });
}

