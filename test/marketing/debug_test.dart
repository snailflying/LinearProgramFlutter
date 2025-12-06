/// 调试测试 - 检查模型构建
import 'package:flutter_test/flutter_test.dart';
import 'package:demo_flutter/marketing/promotion_model.dart';
import 'package:demo_flutter/yalps/yalps.dart';
import 'package:demo_flutter/yalps/solver.dart' as solver;

void main() {
  test('调试 - 简单满额立减', () {
    final products = [
      ProductItem(id: 'T1', name: '商品1', price: 500, quantity: 2),
      ProductItem(id: 'T2', name: '商品2', price: 300, quantity: 2),
    ];

    final promotions = [
      Promotion(
        id: 'P1',
        name: '满1000减100',
        type: PromotionType.amountOff,
        applicableProductIds: ['T1', 'T2'],
        thresholdAmount: 1000,
        discountAmount: 100,
      ),
    ];

    final order = Order(id: 'O1', items: products);
    final solution = PromotionOptimizer.solve([order], promotions);

    print('\n=== 调试信息 ===');
    print('求解状态: ${solution.status}');
    print('总优惠金额: ${solution.totalDiscount}');
    print('订单优惠分配: ${solution.orderPromotion}');
    print('优惠券优惠明细: ${solution.promotionDiscount}');
    print('===============\n');

    // 手动构建模型检查
    final orderPromotionAmount = <String, Map<String, double>>{};
    final orderPromotionCount = <String, Map<String, int>>{};
    
    for (final order in [order]) {
      orderPromotionAmount[order.id] = {};
      orderPromotionCount[order.id] = {};
      
      for (final promotion in promotions) {
        double amount = 0.0;
        int count = 0;
        
        for (final item in order.items) {
          if (promotion.applicableProductIds.contains(item.id)) {
            amount += item.totalAmount;
            count += item.quantity;
          }
        }
        
        orderPromotionAmount[order.id]![promotion.id] = amount;
        orderPromotionCount[order.id]![promotion.id] = count;
      }
    }

    print('订单对活动的可参与金额:');
    orderPromotionAmount.forEach((orderId, amounts) {
      amounts.forEach((promoId, amount) {
        print('  $orderId -> $promoId: $amount');
      });
    });

    print('订单对活动的可参与件数:');
    orderPromotionCount.forEach((orderId, counts) {
      counts.forEach((promoId, count) {
        print('  $orderId -> $promoId: $count');
      });
    });
  });
}

