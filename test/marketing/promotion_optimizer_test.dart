/// 营销活动优化测试
/// 
/// 作者: LiuZhiQiang
/// 测试多个商品、多个优惠券的最优组合选择

import 'package:flutter_test/flutter_test.dart';
import 'package:demo_flutter/marketing/promotion_model.dart';
import 'package:demo_flutter/yalps/yalps.dart';

void main() {
  group('营销活动优化测试', () {
    test('多个商品多个优惠券 - 最优优惠券选择', () {
      // 1. 准备商品数据
      final products = [
        ProductItem(id: 'T1', name: '演唱会A-内场', price: 680, quantity: 2),
        ProductItem(id: 'T2', name: '演唱会A-看台', price: 380, quantity: 3),
        ProductItem(id: 'T3', name: '舞台剧B-普通', price: 260, quantity: 1),
        ProductItem(id: 'T4', name: '舞台剧B-VIP', price: 420, quantity: 2),
        ProductItem(id: 'T5', name: '展览C-单日票', price: 120, quantity: 4),
        ProductItem(id: 'T6', name: '展览C-双人票', price: 200, quantity: 1),
        ProductItem(id: 'T7', name: '乐园D-成人票', price: 399, quantity: 2),
        ProductItem(id: 'T8', name: '乐园D-儿童票', price: 299, quantity: 3),
        ProductItem(id: 'T9', name: '体育E-看台票', price: 480, quantity: 2),
        ProductItem(id: 'T10', name: '体育E-内场票', price: 880, quantity: 1),
      ];

      // 计算总金额
      final totalAmount = products.fold<double>(
        0,
        (sum, p) => sum + p.totalAmount,
      );
      expect(totalAmount, closeTo(7815.0, 0.01));

      // 2. 准备优惠券数据
      final promotions = [
        // 满额立减：演唱会A满2000减150
        Promotion(
          id: 'P1',
          name: '演唱会A满2000减150',
          type: PromotionType.amountOff,
          applicableProductIds: ['T1', 'T2'],
          thresholdAmount: 2000,
          discountAmount: 150,
        ),
        // 满额立减：剧场+展览组合满1000减120
        Promotion(
          id: 'P2',
          name: '剧场+展览组合满1000减120',
          type: PromotionType.amountOff,
          applicableProductIds: ['T3', 'T4', 'T5', 'T6'],
          thresholdAmount: 1000,
          discountAmount: 120,
        ),
        // 满件立减：展览C/乐园D儿童 满5件减80
        Promotion(
          id: 'P3',
          name: '展览C/乐园D儿童 满5件减80',
          type: PromotionType.countOff,
          applicableProductIds: ['T5', 'T8'],
          thresholdCount: 5,
          discountAmount: 80,
        ),
        // 满件立减：乐园成人+体育看台 满3件减150
        Promotion(
          id: 'P4',
          name: '乐园成人+体育看台 满3件减150',
          type: PromotionType.countOff,
          applicableProductIds: ['T7', 'T9'],
          thresholdCount: 3,
          discountAmount: 150,
        ),
        // 每满件立减：剧场+乐园 每满3件减90
        Promotion(
          id: 'P5',
          name: '剧场+乐园 每满3件减90',
          type: PromotionType.eachCountOff,
          applicableProductIds: ['T3', 'T4', 'T7'],
          thresholdCount: 3,
          discountAmountPerStep: 90,
        ),
        // 每满额立减：高价票组合 每满1000减120
        Promotion(
          id: 'P6',
          name: '高价票组合 每满1000减120',
          type: PromotionType.eachAmountOff,
          applicableProductIds: ['T1', 'T10'],
          thresholdAmount: 1000,
          discountAmountPerStep: 120,
        ),
        // 满件打折：看台+儿童+看台票 满5件打8折
        Promotion(
          id: 'P7',
          name: '看台+儿童+看台票 满5件打8折',
          type: PromotionType.countDiscount,
          applicableProductIds: ['T2', 'T8', 'T9'],
          thresholdCount: 5,
          discountRate: 0.8,
        ),
        // 满额打折：VIP/双人/乐园成人 满1000打85折
        Promotion(
          id: 'P8',
          name: 'VIP/双人/乐园成人 满1000打85折',
          type: PromotionType.amountDiscount,
          applicableProductIds: ['T4', 'T6', 'T7'],
          thresholdAmount: 1000,
          discountRate: 0.85,
        ),
        // 每满额立减：全场 每满500减20
        Promotion(
          id: 'P9',
          name: '全场 每满500减20',
          type: PromotionType.eachAmountOff,
          applicableProductIds: [
            'T1',
            'T2',
            'T3',
            'T4',
            'T5',
            'T6',
            'T7',
            'T8',
            'T9',
            'T10'
          ],
          thresholdAmount: 500,
          discountAmountPerStep: 20,
        ),
        // 每满件立减：A/B/展览 每满4件减50
        Promotion(
          id: 'P10',
          name: 'A/B/展览 每满4件减50',
          type: PromotionType.eachCountOff,
          applicableProductIds: ['T1', 'T2', 'T3', 'T4', 'T5'],
          thresholdCount: 4,
          discountAmountPerStep: 50,
        ),
      ];

      // 3. 创建订单
      final order = Order(
        id: 'O1',
        items: products,
      );

      // 4. 求解
      final solution = PromotionOptimizer.solve([order], promotions);

      // 5. 验证结果
      expect(solution.status, SolutionStatus.optimal,
          reason: '应该找到最优解');

      expect(solution.totalDiscount, greaterThan(0.0),
          reason: '总优惠金额应该大于0');

      // 验证订单优惠分配
      expect(solution.orderPromotion.containsKey('O1'), true,
          reason: '应该包含订单O1的优惠分配');

      // 验证优惠金额计算
      final calculatedTotal = solution.promotionDiscount.values.fold<double>(
        0.0,
        (sum, discount) => sum + discount,
      );
      expect(
        calculatedTotal,
        closeTo(solution.totalDiscount, 0.1),
        reason: '各优惠券优惠金额之和应该等于总优惠金额',
      );

      // 打印结果用于验证
      print('\n=== 营销活动优化测试结果 ===');
      print('总商品金额: ¥${totalAmount.toStringAsFixed(2)}');
      print('总优惠金额: ¥${solution.totalDiscount.toStringAsFixed(2)}');
      print('实付金额: ¥${(totalAmount - solution.totalDiscount).toStringAsFixed(2)}');
      print('\n订单优惠分配:');
      solution.orderPromotion.forEach((orderId, promotionId) {
        if (promotionId != null) {
          final promotion = promotions.firstWhere((p) => p.id == promotionId);
          final discount = solution.promotionDiscount[promotionId] ?? 0.0;
          print('  $orderId -> ${promotion.name} (优惠¥${discount.toStringAsFixed(2)})');
        } else {
          print('  $orderId -> 未使用优惠券');
        }
      });
      print('\n各优惠券优惠明细:');
      solution.promotionDiscount.forEach((promotionId, discount) {
        final promotion = promotions.firstWhere((p) => p.id == promotionId);
        print('  ${promotion.name}: ¥${discount.toStringAsFixed(2)}');
      });
      print('==========================\n');
    });

    test('简单场景 - 单个满额立减优惠券', () {
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

      expect(solution.status, SolutionStatus.optimal);
      expect(solution.totalDiscount, closeTo(100.0, 0.1));
    });

    test('简单场景 - 满件立减优惠券', () {
      final products = [
        ProductItem(id: 'T1', name: '商品1', price: 100, quantity: 3),
        ProductItem(id: 'T2', name: '商品2', price: 200, quantity: 2),
      ];

      final promotions = [
        Promotion(
          id: 'P1',
          name: '满5件减50',
          type: PromotionType.countOff,
          applicableProductIds: ['T1', 'T2'],
          thresholdCount: 5,
          discountAmount: 50,
        ),
      ];

      final order = Order(id: 'O1', items: products);
      final solution = PromotionOptimizer.solve([order], promotions);

      expect(solution.status, SolutionStatus.optimal);
      expect(solution.totalDiscount, closeTo(50.0, 0.1));
    });

    test('每满额立减 - 多步触发', () {
      final products = [
        ProductItem(id: 'T1', name: '商品1', price: 600, quantity: 3),
      ];

      final promotions = [
        Promotion(
          id: 'P1',
          name: '每满500减50',
          type: PromotionType.eachAmountOff,
          applicableProductIds: ['T1'],
          thresholdAmount: 500,
          discountAmountPerStep: 50,
        ),
      ];

      final order = Order(id: 'O1', items: products);
      final solution = PromotionOptimizer.solve([order], promotions);

      expect(solution.status, SolutionStatus.optimal);
      // 1800 / 500 = 3.6 -> floor(3.6) = 3步，优惠 3 * 50 = 150
      expect(solution.totalDiscount, closeTo(150.0, 1.0));
    });

    test('满额打折优惠券', () {
      final products = [
        ProductItem(id: 'T1', name: '商品1', price: 400, quantity: 2),
        ProductItem(id: 'T2', name: '商品2', price: 300, quantity: 1),
      ];

      final promotions = [
        Promotion(
          id: 'P1',
          name: '满1000打8折',
          type: PromotionType.amountDiscount,
          applicableProductIds: ['T1', 'T2'],
          thresholdAmount: 1000,
          discountRate: 0.8,
        ),
      ];

      final order = Order(id: 'O1', items: products);
      final solution = PromotionOptimizer.solve([order], promotions);

      expect(solution.status, SolutionStatus.optimal);
      // 总金额 1100，打8折，优惠 (1-0.8) * 1100 = 220
      expect(solution.totalDiscount, closeTo(220.0, 1.0));
    });
  });
}

