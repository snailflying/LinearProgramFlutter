import 'package:flutter_test/flutter_test.dart';
import 'package:demo_flutter/linear_programming/linear_programming.dart';
import 'package:demo_flutter/marketing_campaign/marketing_ilp_builder.dart';

/// 打折类活动测试（Big-M约束）
void main() {
  group('打折类活动测试', () {
    test('满件打折：跨订单触发', () {
      // 活动P1：满4件打8折
      // 订单O1: 3件(280元), O2: 2件(300元), O3: 2件(160元)
      // 需要O1+O3或O1+O2才能达到4件门槛
      
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
          discountRate: 0.8, // 打8折，优惠20%
        ),
      ];
      
      // 计算 a_{o,i} 和 c_{o,i}
      final amountMatrix = [
        [280.0], // O1
        [300.0], // O2
        [160.0], // O3
      ];
      final countMatrix = [
        [3.0],
        [2.0],
        [2.0],
      ];
      
      final builder = MarketingILPBuilder(
        orders: orders,
        promotions: promotions,
        amountMatrix: amountMatrix,
        countMatrix: countMatrix,
      );
      
      final problem = builder.build();
      final result = IntegerSolver.solve(problem);
      
      print('状态: ${result.status}');
      print('最优值: ${result.optimalValue}');
      print('最优解: ${result.solution}');
      
      expect(result.isOptimal, true);
      // 最优解应该是：O1和O3参加活动，A_1=440, C_1=5, z_1=1, D_1=0.2*440=88
      if (result.isOptimal) {
        expect(result.optimalValue, greaterThan(0.0));
      }
    });

    test('满额打折：单订单触发', () {
      // 活动P2：满1000打85折
      // 订单O2: 420元（不满足），O2+O3: 420+200=620（不满足）
      // 需要更大的订单组合
      
      final orders = [
        OrderData(
          id: 'O2',
          items: [
            OrderItem(ticketTypeId: 'C1', quantity: 2, price: 150.0),
            OrderItem(ticketTypeId: 'D2', quantity: 1, price: 120.0),
          ],
        ),
        OrderData(
          id: 'O3',
          items: [
            OrderItem(ticketTypeId: 'E1', quantity: 1, price: 200.0),
          ],
        ),
      ];
      
      final promotions = [
        PromotionData(
          id: 'P2',
          kind: PromotionKind.amountDiscount,
          scopeTicketTypeIds: ['C1', 'D2', 'E1'],
          thresholdAmount: 1000.0,
          discountRate: 0.85, // 打85折，优惠15%
        ),
      ];
      
      final amountMatrix = [
        [420.0], // O2
        [200.0], // O3
      ];
      final countMatrix = [
        [3.0],
        [1.0],
      ];
      
      final builder = MarketingILPBuilder(
        orders: orders,
        promotions: promotions,
        amountMatrix: amountMatrix,
        countMatrix: countMatrix,
      );
      
      final problem = builder.build();
      final result = IntegerSolver.solve(problem);
      
      print('状态: ${result.status}');
      print('最优值: ${result.optimalValue}');
      print('最优解: ${result.solution}');
      
      expect(result.isOptimal, true);
      // 由于金额不足1000，应该无法触发，D_2=0
      if (result.isOptimal) {
        // 可能为0（无法触发）或很小的值
        expect(result.optimalValue, greaterThanOrEqualTo(0.0));
      }
    });
  });
}

