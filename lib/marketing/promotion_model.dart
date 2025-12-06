/// 营销活动优化模型
/// 
/// 作者: LiuZhiQiang
/// 将营销活动问题转换为 ILP 模型并使用 YALPS 求解

import 'package:demo_flutter/yalps/yalps.dart';
import 'package:demo_flutter/yalps/types.dart';
import 'package:demo_flutter/yalps/solver.dart' as solver;

/// 商品项
class ProductItem {
  final String id;
  final String name;
  final double price;
  final int quantity;

  ProductItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
  });

  double get totalAmount => price * quantity;
}

/// 活动类型
enum PromotionType {
  /// 满额立减
  amountOff,
  /// 满件立减
  countOff,
  /// 每满额立减
  eachAmountOff,
  /// 每满件立减
  eachCountOff,
  /// 满额打折
  amountDiscount,
  /// 满件打折
  countDiscount,
}

/// 优惠券/活动
class Promotion {
  final String id;
  final String name;
  final PromotionType type;
  final List<String> applicableProductIds; // 适用的商品ID列表
  final double? thresholdAmount; // 金额门槛
  final int? thresholdCount; // 件数门槛
  final double? discountAmount; // 立减金额
  final double? discountRate; // 折扣率 (0-1)
  final double? discountAmountPerStep; // 每满的立减金额

  Promotion({
    required this.id,
    required this.name,
    required this.type,
    required this.applicableProductIds,
    this.thresholdAmount,
    this.thresholdCount,
    this.discountAmount,
    this.discountRate,
    this.discountAmountPerStep,
  });
}

/// 订单
class Order {
  final String id;
  final List<ProductItem> items;

  Order({
    required this.id,
    required this.items,
  });
}

/// 求解结果
class PromotionSolution {
  final Map<String, String?> orderPromotion; // 订单ID -> 活动ID（null表示不参加任何活动）
  final Map<String, double> promotionDiscount; // 活动ID -> 优惠金额
  final double totalDiscount; // 总优惠金额
  final SolutionStatus status;

  PromotionSolution({
    required this.orderPromotion,
    required this.promotionDiscount,
    required this.totalDiscount,
    required this.status,
  });
}

/// 营销活动优化求解器
class PromotionOptimizer {
  /// 将营销活动问题转换为 ILP 模型并求解
  static PromotionSolution solve(
    List<Order> orders,
    List<Promotion> promotions,
  ) {
    // 1. 预处理：计算每个订单对每个活动的可参与金额和件数
    final (orderPromotionAmount, orderPromotionCount) =
        _calculateOrderPromotionData(orders, promotions);

    // 2. 计算每个活动的最大可能金额和件数（用于 big-M）
    final (maxAmount, maxCount) =
        _calculateMaxAmountAndCount(orders, promotions, orderPromotionAmount, orderPromotionCount);

    // 3. 构建 YALPS Model
    final model = _buildModel(
      orders,
      promotions,
      orderPromotionAmount,
      orderPromotionCount,
      maxAmount,
      maxCount,
    );

    // 4. 求解
    final yalpsSolution = solver.solve(model, DefaultOptions.create());

    // 5. 解析结果
    return _parseSolution(orders, promotions, yalpsSolution);
  }

  /// 计算每个订单对每个活动的可参与金额和件数
  static (Map<String, Map<String, double>>, Map<String, Map<String, int>>)
      _calculateOrderPromotionData(
    List<Order> orders,
    List<Promotion> promotions,
  ) {
    final Map<String, Map<String, double>> orderPromotionAmount = {};
    final Map<String, Map<String, int>> orderPromotionCount = {};

    for (final order in orders) {
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

    return (orderPromotionAmount, orderPromotionCount);
  }

  /// 计算每个活动的最大可能金额和件数（用于 big-M）
  static (Map<String, double>, Map<String, int>) _calculateMaxAmountAndCount(
    List<Order> orders,
    List<Promotion> promotions,
    Map<String, Map<String, double>> orderPromotionAmount,
    Map<String, Map<String, int>> orderPromotionCount,
  ) {
    final Map<String, double> maxAmount = {};
    final Map<String, int> maxCount = {};

    for (final promotion in promotions) {
      double totalAmount = 0.0;
      int totalCount = 0;

      for (final order in orders) {
        totalAmount += orderPromotionAmount[order.id]![promotion.id] ?? 0.0;
        totalCount += orderPromotionCount[order.id]![promotion.id] ?? 0;
      }

      maxAmount[promotion.id] = totalAmount;
      maxCount[promotion.id] = totalCount;
    }

    return (maxAmount, maxCount);
  }

  /// 构建 YALPS Model
  static Model<String, String> _buildModel(
    List<Order> orders,
    List<Promotion> promotions,
    Map<String, Map<String, double>> orderPromotionAmount,
    Map<String, Map<String, int>> orderPromotionCount,
    Map<String, double> maxAmount,
    Map<String, int> maxCount,
  ) {
    final constraints = <String, Constraint>{};
    final variables = <String, Map<String, double>>{};
    final integers = <String>[];

    // 目标函数通过 objective 字段指定，不需要在 constraints 中定义
    // 目标函数的系数通过变量在 'OBJ' 约束上的系数来定义

    // 每个订单最多参加一个活动
    _addOrderConstraints(orders, promotions, constraints, variables, integers);

    // 每个活动的金额和件数聚合约束
    _addAggregationConstraints(
      orders,
      promotions,
      orderPromotionAmount,
      orderPromotionCount,
      constraints,
      variables,
    );

    // 根据活动类型添加约束
    _addPromotionTypeConstraints(
      promotions,
      maxAmount,
      maxCount,
      constraints,
      variables,
      integers,
    );

    return Model<String, String>(
      direction: OptimizationDirection.maximize,
      objective: 'OBJ',
      constraints: constraints,
      variables: variables,
      integers: integers,
    );
  }

  /// 添加订单约束：每个订单最多参加一个活动
  static void _addOrderConstraints(
    List<Order> orders,
    List<Promotion> promotions,
    Map<String, Constraint> constraints,
    Map<String, Map<String, double>> variables,
    List<String> integers,
  ) {
    for (final order in orders) {
      final constraintName = 'order_${order.id}';
      constraints[constraintName] = Constraint(max: 1.0);

      for (final promotion in promotions) {
        final varName = 'y_${order.id}_${promotion.id}';
        if (!variables.containsKey(varName)) {
          variables[varName] = {};
        }
        variables[varName]![constraintName] = 1.0;
        integers.add(varName);
      }
    }
  }

  /// 添加聚合约束：每个活动的金额和件数聚合
  static void _addAggregationConstraints(
    List<Order> orders,
    List<Promotion> promotions,
    Map<String, Map<String, double>> orderPromotionAmount,
    Map<String, Map<String, int>> orderPromotionCount,
    Map<String, Constraint> constraints,
    Map<String, Map<String, double>> variables,
  ) {
    for (final promotion in promotions) {
      // A_i = sum(a_o_i * y_o_i)
      final amountConstraintName = 'A_${promotion.id}';
      constraints[amountConstraintName] = Constraint(equal: 0.0);

      // C_i = sum(c_o_i * y_o_i)
      final countConstraintName = 'C_${promotion.id}';
      constraints[countConstraintName] = Constraint(equal: 0.0);

      // A_i 变量
      final amountVarName = 'A_${promotion.id}';
      if (!variables.containsKey(amountVarName)) {
        variables[amountVarName] = {};
      }
      variables[amountVarName]![amountConstraintName] = -1.0;

      // C_i 变量
      final countVarName = 'C_${promotion.id}';
      if (!variables.containsKey(countVarName)) {
        variables[countVarName] = {};
      }
      variables[countVarName]![countConstraintName] = -1.0;

      // y_o_i 变量对聚合约束的贡献
      for (final order in orders) {
        final varName = 'y_${order.id}_${promotion.id}';
        final amount = orderPromotionAmount[order.id]![promotion.id] ?? 0.0;
        final count = orderPromotionCount[order.id]![promotion.id] ?? 0;

        if (amount > 0 || count > 0) {
          if (!variables.containsKey(varName)) {
            variables[varName] = {};
          }
          variables[varName]![amountConstraintName] = amount;
          variables[varName]![countConstraintName] = count.toDouble();
        }
      }
    }
  }

  /// 根据活动类型添加约束
  static void _addPromotionTypeConstraints(
    List<Promotion> promotions,
    Map<String, double> maxAmount,
    Map<String, int> maxCount,
    Map<String, Constraint> constraints,
    Map<String, Map<String, double>> variables,
    List<String> integers,
  ) {
    for (final promotion in promotions) {
      _addSinglePromotionConstraints(
        promotion,
        maxAmount,
        maxCount,
        constraints,
        variables,
        integers,
      );
    }
  }

  /// 为单个活动添加约束
  static void _addSinglePromotionConstraints(
    Promotion promotion,
    Map<String, double> maxAmount,
    Map<String, int> maxCount,
    Map<String, Constraint> constraints,
    Map<String, Map<String, double>> variables,
    List<String> integers,
  ) {
    final amountVarName = 'A_${promotion.id}';
    final countVarName = 'C_${promotion.id}';

    switch (promotion.type) {
      case PromotionType.amountOff:
        _addAmountOffConstraints(
          promotion,
          amountVarName,
          maxAmount[promotion.id]!,
          constraints,
          variables,
          integers,
        );
        break;
      case PromotionType.countOff:
        _addCountOffConstraints(
          promotion,
          countVarName,
          maxCount[promotion.id]!,
          constraints,
          variables,
          integers,
        );
        break;
      case PromotionType.eachAmountOff:
        _addEachAmountOffConstraints(
          promotion,
          amountVarName,
          maxAmount[promotion.id]!,
          constraints,
          variables,
          integers,
        );
        break;
      case PromotionType.eachCountOff:
        _addEachCountOffConstraints(
          promotion,
          countVarName,
          maxCount[promotion.id]!,
          constraints,
          variables,
          integers,
        );
        break;
      case PromotionType.amountDiscount:
        _addAmountDiscountConstraints(
          promotion,
          amountVarName,
          maxAmount[promotion.id]!,
          constraints,
          variables,
          integers,
        );
        break;
      case PromotionType.countDiscount:
        _addCountDiscountConstraints(
          promotion,
          countVarName,
          amountVarName,
          maxAmount[promotion.id]!,
          maxCount[promotion.id]!,
          constraints,
          variables,
          integers,
        );
        break;
    }
  }

  /// 解析求解结果
  static PromotionSolution _parseSolution(
    List<Order> orders,
    List<Promotion> promotions,
    Solution<String> yalpsSolution,
  ) {
    final orderPromotion = <String, String?>{};
    final promotionDiscount = <String, double>{};

    for (final order in orders) {
      String? selectedPromotion;
      for (final promotion in promotions) {
        final varName = 'y_${order.id}_${promotion.id}';
        final varValue = yalpsSolution.variables.firstWhere(
          (v) => v.$1 == varName,
          orElse: () => ('', 0.0),
        ).$2;
        if (varValue > 0.5) {
          selectedPromotion = promotion.id;
          break;
        }
      }
      orderPromotion[order.id] = selectedPromotion;
    }

    for (final promotion in promotions) {
      final discountVarName = 'D_${promotion.id}';
      final discountValue = yalpsSolution.variables.firstWhere(
        (v) => v.$1 == discountVarName,
        orElse: () => ('', 0.0),
      ).$2;
      if (discountValue > 0.01) {
        promotionDiscount[promotion.id] = discountValue;
      }
    }

    return PromotionSolution(
      orderPromotion: orderPromotion,
      promotionDiscount: promotionDiscount,
      totalDiscount: yalpsSolution.result.isFinite ? yalpsSolution.result : 0.0,
      status: yalpsSolution.status,
    );
  }

  // 满额立减约束
  static void _addAmountOffConstraints(
    Promotion promotion,
    String amountVarName,
    double maxAmount,
    Map<String, Constraint> constraints,
    Map<String, Map<String, double>> variables,
    List<String> integers,
  ) {
    final threshold = promotion.thresholdAmount!;
    final discount = promotion.discountAmount!;
    
    // t_i 变量
    final tVarName = 't_${promotion.id}';
    if (!variables.containsKey(tVarName)) {
      variables[tVarName] = {};
    }
    integers.add(tVarName);
    variables[tVarName]!['t_${promotion.id}_max'] = 1.0;

    // t_i <= 1
    constraints['t_${promotion.id}_max'] = Constraint(max: 1.0);

    // A_i >= T * t_i  =>  -A_i + T * t_i <= 0
    constraints['threshold_${promotion.id}'] = Constraint(max: 0.0);
    variables[amountVarName]!['threshold_${promotion.id}'] = -1.0;
    variables[tVarName]!['threshold_${promotion.id}'] = threshold;

    // D_i = L * t_i  =>  D_i - L * t_i = 0
    final dVarName = 'D_${promotion.id}';
    if (!variables.containsKey(dVarName)) {
      variables[dVarName] = {};
    }
    variables[dVarName]!['OBJ'] = 1.0; // 目标函数
    constraints['discount_${promotion.id}'] = Constraint(equal: 0.0);
    variables[dVarName]!['discount_${promotion.id}'] = 1.0;
    variables[tVarName]!['discount_${promotion.id}'] = -discount;
  }

  // 满件立减约束
  static void _addCountOffConstraints(
    Promotion promotion,
    String countVarName,
    int maxCount,
    Map<String, Constraint> constraints,
    Map<String, Map<String, double>> variables,
    List<String> integers,
  ) {
    final threshold = promotion.thresholdCount!.toDouble();
    final discount = promotion.discountAmount!;
    
    final tVarName = 't_${promotion.id}';
    if (!variables.containsKey(tVarName)) {
      variables[tVarName] = {};
    }
    integers.add(tVarName);
    variables[tVarName]!['t_${promotion.id}_max'] = 1.0;
    constraints['t_${promotion.id}_max'] = Constraint(max: 1.0);

    constraints['threshold_${promotion.id}'] = Constraint(max: 0.0);
    variables[countVarName]!['threshold_${promotion.id}'] = -1.0;
    variables[tVarName]!['threshold_${promotion.id}'] = threshold;

    final dVarName = 'D_${promotion.id}';
    if (!variables.containsKey(dVarName)) {
      variables[dVarName] = {};
    }
    variables[dVarName]!['OBJ'] = 1.0;
    constraints['discount_${promotion.id}'] = Constraint(equal: 0.0);
    variables[dVarName]!['discount_${promotion.id}'] = 1.0;
    variables[tVarName]!['discount_${promotion.id}'] = -discount;
  }

  // 每满额立减约束
  static void _addEachAmountOffConstraints(
    Promotion promotion,
    String amountVarName,
    double maxAmount,
    Map<String, Constraint> constraints,
    Map<String, Map<String, double>> variables,
    List<String> integers,
  ) {
    final threshold = promotion.thresholdAmount!;
    final discount = promotion.discountAmountPerStep!;
    final maxT = (maxAmount / threshold).floor();
    
    final tVarName = 't_${promotion.id}';
    if (!variables.containsKey(tVarName)) {
      variables[tVarName] = {};
    }
    integers.add(tVarName);
    variables[tVarName]!['t_${promotion.id}_max'] = 1.0;
    constraints['t_${promotion.id}_max'] = Constraint(max: maxT.toDouble());

    constraints['threshold_${promotion.id}'] = Constraint(max: 0.0);
    variables[amountVarName]!['threshold_${promotion.id}'] = -1.0;
    variables[tVarName]!['threshold_${promotion.id}'] = threshold;

    final dVarName = 'D_${promotion.id}';
    if (!variables.containsKey(dVarName)) {
      variables[dVarName] = {};
    }
    variables[dVarName]!['OBJ'] = 1.0;
    constraints['discount_${promotion.id}'] = Constraint(equal: 0.0);
    variables[dVarName]!['discount_${promotion.id}'] = 1.0;
    variables[tVarName]!['discount_${promotion.id}'] = -discount;
  }

  // 每满件立减约束
  static void _addEachCountOffConstraints(
    Promotion promotion,
    String countVarName,
    int maxCount,
    Map<String, Constraint> constraints,
    Map<String, Map<String, double>> variables,
    List<String> integers,
  ) {
    final threshold = promotion.thresholdCount!.toDouble();
    final discount = promotion.discountAmountPerStep!;
    final maxT = (maxCount / promotion.thresholdCount!).floor();
    
    final tVarName = 't_${promotion.id}';
    if (!variables.containsKey(tVarName)) {
      variables[tVarName] = {};
    }
    integers.add(tVarName);
    variables[tVarName]!['t_${promotion.id}_max'] = 1.0;
    constraints['t_${promotion.id}_max'] = Constraint(max: maxT.toDouble());

    constraints['threshold_${promotion.id}'] = Constraint(max: 0.0);
    variables[countVarName]!['threshold_${promotion.id}'] = -1.0;
    variables[tVarName]!['threshold_${promotion.id}'] = threshold;

    final dVarName = 'D_${promotion.id}';
    if (!variables.containsKey(dVarName)) {
      variables[dVarName] = {};
    }
    variables[dVarName]!['OBJ'] = 1.0;
    constraints['discount_${promotion.id}'] = Constraint(equal: 0.0);
    variables[dVarName]!['discount_${promotion.id}'] = 1.0;
    variables[tVarName]!['discount_${promotion.id}'] = -discount;
  }

  // 满额打折约束
  static void _addAmountDiscountConstraints(
    Promotion promotion,
    String amountVarName,
    double maxAmount,
    Map<String, Constraint> constraints,
    Map<String, Map<String, double>> variables,
    List<String> integers,
  ) {
    final threshold = promotion.thresholdAmount!;
    final rate = promotion.discountRate!;
    final discountRate = 1.0 - rate;
    
    // z_i 变量
    final zVarName = 'z_${promotion.id}';
    if (!variables.containsKey(zVarName)) {
      variables[zVarName] = {};
    }
    integers.add(zVarName);

    // A_i >= T * z_i  =>  -A_i + T * z_i <= 0
    constraints['threshold_${promotion.id}'] = Constraint(max: 0.0);
    variables[amountVarName]!['threshold_${promotion.id}'] = -1.0;
    variables[zVarName]!['threshold_${promotion.id}'] = threshold;

    // D_i = (1-r) * A_i (big-M 线性化)
    final dVarName = 'D_${promotion.id}';
    if (!variables.containsKey(dVarName)) {
      variables[dVarName] = {};
    }
    variables[dVarName]!['OBJ'] = 1.0;

    // D_i <= (1-r) * A_i
    constraints['discount_upper_${promotion.id}'] = Constraint(max: 0.0);
    variables[dVarName]!['discount_upper_${promotion.id}'] = 1.0;
    variables[amountVarName]!['discount_upper_${promotion.id}'] = -discountRate;

    // D_i >= (1-r) * A_i - (1-r) * M * (1-z_i)
    // => D_i - (1-r) * A_i + (1-r) * M * z_i >= (1-r) * M
    constraints['discount_lower_${promotion.id}'] = Constraint(min: -discountRate * maxAmount);
    variables[dVarName]!['discount_lower_${promotion.id}'] = 1.0;
    variables[amountVarName]!['discount_lower_${promotion.id}'] = -discountRate;
    variables[zVarName]!['discount_lower_${promotion.id}'] = discountRate * maxAmount;

    // D_i <= (1-r) * M * z_i
    constraints['discount_bound_${promotion.id}'] = Constraint(max: 0.0);
    variables[dVarName]!['discount_bound_${promotion.id}'] = 1.0;
    variables[zVarName]!['discount_bound_${promotion.id}'] = -discountRate * maxAmount;
  }

  // 满件打折约束
  static void _addCountDiscountConstraints(
    Promotion promotion,
    String countVarName,
    String amountVarName,
    double maxAmount,
    int maxCount,
    Map<String, Constraint> constraints,
    Map<String, Map<String, double>> variables,
    List<String> integers,
  ) {
    final threshold = promotion.thresholdCount!.toDouble();
    final rate = promotion.discountRate!;
    final discountRate = 1.0 - rate;
    
    final zVarName = 'z_${promotion.id}';
    if (!variables.containsKey(zVarName)) {
      variables[zVarName] = {};
    }
    integers.add(zVarName);

    // C_i >= T * z_i
    constraints['threshold_${promotion.id}'] = Constraint(max: 0.0);
    variables[countVarName]!['threshold_${promotion.id}'] = -1.0;
    variables[zVarName]!['threshold_${promotion.id}'] = threshold;

    // D_i = (1-r) * A_i (big-M 线性化)
    final dVarName = 'D_${promotion.id}';
    if (!variables.containsKey(dVarName)) {
      variables[dVarName] = {};
    }
    variables[dVarName]!['OBJ'] = 1.0;

    constraints['discount_upper_${promotion.id}'] = Constraint(max: 0.0);
    variables[dVarName]!['discount_upper_${promotion.id}'] = 1.0;
    variables[amountVarName]!['discount_upper_${promotion.id}'] = -discountRate;

    constraints['discount_lower_${promotion.id}'] = Constraint(min: -discountRate * maxAmount);
    variables[dVarName]!['discount_lower_${promotion.id}'] = 1.0;
    variables[amountVarName]!['discount_lower_${promotion.id}'] = -discountRate;
    variables[zVarName]!['discount_lower_${promotion.id}'] = discountRate * maxAmount;

    constraints['discount_bound_${promotion.id}'] = Constraint(max: 0.0);
    variables[dVarName]!['discount_bound_${promotion.id}'] = 1.0;
    variables[zVarName]!['discount_bound_${promotion.id}'] = -discountRate * maxAmount;
  }
}

