import 'package:demo_flutter/linear_programming/linear_programming.dart';
import 'package:demo_flutter/linear_programming/big_m_constraints.dart';

/// 营销活动ILP模型构建器
/// 
/// 基于docs文档中的营销活动数学建模模型
class MarketingILPBuilder {
  /// 订单数据
  final List<OrderData> orders;
  
  /// 活动数据
  final List<PromotionData> promotions;
  
  /// 订单×活动的金额矩阵 a_{o,i}
  final List<List<double>> amountMatrix;
  
  /// 订单×活动的件数矩阵 c_{o,i}
  final List<List<double>> countMatrix;

  MarketingILPBuilder({
    required this.orders,
    required this.promotions,
    required this.amountMatrix,
    required this.countMatrix,
  });

  /// 构建完整的ILP模型
  LinearProgram build() {
    // 简化版本：先只处理立减类活动（不需要Big-M）
    return _buildSimplifiedModel();
  }

  /// 构建简化模型（只处理立减类活动）
  LinearProgram _buildSimplifiedModel() {
    final numOrders = orders.length;
    final numPromotions = promotions.length;
    
    // 处理所有活动类型（包括打折类）
    final validPromotions = <int>[];
    for (var i = 0; i < numPromotions; i++) {
      validPromotions.add(i);
    }
    
    final numValidPromotions = validPromotions.length;
    if (numValidPromotions == 0) {
      // 没有有效的立减类活动，返回一个空问题
      return LinearProgram(
        optimizationType: OptimizationType.maximize,
        objectiveCoefficients: [0.0],
        constraintMatrix: [],
        constraintRhs: [],
        constraintTypes: [],
      );
    }
    
    // 变量布局：
    // [0 .. numOrders*numValidPromotions-1]: y_{o,i}
    // [numOrders*numValidPromotions .. numOrders*numValidPromotions+numValidPromotions-1]: A_i
    // [numOrders*numValidPromotions+numValidPromotions .. numOrders*numValidPromotions+2*numValidPromotions-1]: C_i
    // [numOrders*numValidPromotions+2*numValidPromotions .. numOrders*numValidPromotions+3*numValidPromotions-1]: D_i
    // [numOrders*numValidPromotions+3*numValidPromotions .. numOrders*numValidPromotions+4*numValidPromotions-1]: t_i (立减类) 或 z_i (打折类)
    // 计算打折类活动数量
    var discountCount = 0;
    for (var idx = 0; idx < numValidPromotions; idx++) {
      final i = validPromotions[idx];
      if (promotions[i].kind == PromotionKind.amountDiscount ||
          promotions[i].kind == PromotionKind.countDiscount) {
        discountCount++;
      }
    }
    
    // 总变量数 = numOrders * numValidPromotions + 4 * numValidPromotions + discountCount
    // (4个连续变量：A, C, D, t/z，其中t和z共享索引空间，但打折类需要额外的z变量)
    final totalVars = numOrders * numValidPromotions + 4 * numValidPromotions + discountCount;
    
    // 目标函数：最大化总优惠金额 sum D_i
    final objective = List<double>.filled(totalVars, 0.0);
    for (var idx = 0; idx < numValidPromotions; idx++) {
      // D_i的索引
      final dIndex = numOrders * numValidPromotions + 2 * numValidPromotions + idx;
      objective[dIndex] = 1.0;
    }
    
    final constraints = <List<double>>[];
    final rhs = <double>[];
    final types = <ConstraintType>[];
    final integerVars = <int>{};
    
    // 1. 每个订单最多参加一个活动
    for (var o = 0; o < numOrders; o++) {
      final row = List<double>.filled(totalVars, 0.0);
      for (var idx = 0; idx < numValidPromotions; idx++) {
        final yIndex = o * numValidPromotions + idx;
        row[yIndex] = 1.0;
        integerVars.add(yIndex);
      }
      constraints.add(row);
      rhs.add(1.0);
      types.add(ConstraintType.lessThanOrEqual);
    }
    
    // 2. A_i和C_i的定义约束
    for (var idx = 0; idx < numValidPromotions; idx++) {
      final i = validPromotions[idx];
      final aIndex = numOrders * numValidPromotions + idx;
      final cIndex = numOrders * numValidPromotions + numValidPromotions + idx;
      
      // A_i = sum_o a_{o,i} * y_{o,i}
      final aRow = List<double>.filled(totalVars, 0.0);
      aRow[aIndex] = 1.0; // A_i
      for (var o = 0; o < numOrders; o++) {
        final yIndex = o * numValidPromotions + idx;
        aRow[yIndex] = -amountMatrix[o][i];
      }
      constraints.add(aRow);
      rhs.add(0.0);
      types.add(ConstraintType.equal);
      
      // C_i = sum_o c_{o,i} * y_{o,i}
      final cRow = List<double>.filled(totalVars, 0.0);
      cRow[cIndex] = 1.0; // C_i
      for (var o = 0; o < numOrders; o++) {
        final yIndex = o * numValidPromotions + idx;
        cRow[yIndex] = -countMatrix[o][i];
      }
      constraints.add(cRow);
      rhs.add(0.0);
      types.add(ConstraintType.equal);
    }
    
    // 3. 活动类型约束
    for (var idx = 0; idx < numValidPromotions; idx++) {
      final i = validPromotions[idx];
      final promo = promotions[i];
      final aIndex = numOrders * numValidPromotions + idx;
      final cIndex = numOrders * numValidPromotions + numValidPromotions + idx;
      final dIndex = numOrders * numValidPromotions + 2 * numValidPromotions + idx;
      final tIndex = numOrders * numValidPromotions + 3 * numValidPromotions + idx;
      
      switch (promo.kind) {
        case PromotionKind.amountOff:
        case PromotionKind.countOff:
          // 满减：单次触发
          // A_i >= T_i * t_i (或 C_i >= T_i * t_i)
          // 0 <= t_i <= 1
          // D_i = L_i * t_i
          final threshold = (promo.thresholdAmount ?? promo.thresholdCount ?? 0.0).toDouble();
          final discount = (promo.discountAmount ?? 0.0).toDouble();
          
          final thresholdRow = List<double>.filled(totalVars, 0.0);
          if (promo.kind == PromotionKind.amountOff) {
            thresholdRow[aIndex] = 1.0;
          } else {
            thresholdRow[cIndex] = 1.0;
          }
          thresholdRow[tIndex] = -threshold;
          constraints.add(thresholdRow);
          rhs.add(0.0);
          types.add(ConstraintType.greaterThanOrEqual);
          
          // D_i = L_i * t_i
          final discountRow = List<double>.filled(totalVars, 0.0);
          discountRow[dIndex] = 1.0;
          discountRow[tIndex] = -discount;
          constraints.add(discountRow);
          rhs.add(0.0);
          types.add(ConstraintType.equal);
          
          integerVars.add(tIndex);
          break;
          
        case PromotionKind.eachAmountOff:
        case PromotionKind.eachCountOff:
          // 每满减：可多次触发
          // A_i >= T_i * t_i (或 C_i >= T_i * t_i)
          // 0 <= t_i <= max_t_i
          // D_i = L_i * t_i
          final step = (promo.stepAmount ?? (promo.stepCount ?? 0).toDouble()).toDouble();
          final discountPerStep = (promo.discountAmountPerStep ?? 0.0).toDouble();
          
          final thresholdRow = List<double>.filled(totalVars, 0.0);
          if (promo.kind == PromotionKind.eachAmountOff) {
            thresholdRow[aIndex] = 1.0;
          } else {
            thresholdRow[cIndex] = 1.0;
          }
          thresholdRow[tIndex] = -step;
          constraints.add(thresholdRow);
          rhs.add(0.0);
          types.add(ConstraintType.greaterThanOrEqual);
          
          // D_i = L_i * t_i
          final discountRow = List<double>.filled(totalVars, 0.0);
          discountRow[dIndex] = 1.0;
          discountRow[tIndex] = -discountPerStep;
          constraints.add(discountRow);
          rhs.add(0.0);
          types.add(ConstraintType.equal);
          
          integerVars.add(tIndex);
          break;
          
        case PromotionKind.amountDiscount:
        case PromotionKind.countDiscount:
          // 打折类：使用Big-M约束
          // z_i变量索引：在t_i之后，需要单独计算
          var zIndexOffset = 0;
          for (var prevIdx = 0; prevIdx < idx; prevIdx++) {
            final prevI = validPromotions[prevIdx];
            final prevPromo = promotions[prevI];
            if (prevPromo.kind == PromotionKind.amountDiscount ||
                prevPromo.kind == PromotionKind.countDiscount) {
              zIndexOffset++;
            }
          }
          final zIndex = numOrders * numValidPromotions + 3 * numValidPromotions + numValidPromotions + zIndexOffset;
          
          // 计算Big-M常数：M = sum_o a_{o,i}
          var bigM = 0.0;
          for (var o = 0; o < numOrders; o++) {
            bigM += amountMatrix[o][i];
          }
          
          final threshold = (promo.thresholdAmount ?? promo.thresholdCount ?? 0.0).toDouble();
          final discountRate = promo.discountRate ?? 1.0;
          final useAmount = promo.kind == PromotionKind.amountDiscount;
          
          // 构建Big-M约束
          final bigMConstraints = BigMConstraints.buildDiscountConstraints(
            aIndex: aIndex,
            cIndex: cIndex,
            dIndex: dIndex,
            zIndex: zIndex,
            threshold: threshold,
            discountRate: discountRate,
            bigM: bigM,
            useAmount: useAmount,
            totalVars: totalVars,
          );
          
          // 添加Big-M约束
          for (final constraint in bigMConstraints) {
            constraints.add(constraint['matrix'] as List<double>);
            rhs.add(constraint['rhs'] as double);
            types.add(constraint['type'] as ConstraintType);
          }
          
          // z_i是整数变量（0或1）
          integerVars.add(zIndex);
          break;
      }
    }
    
    // 变量上界
    final upperBounds = List<double>.filled(totalVars, double.infinity);
    var discountIdx = 0;
    for (var idx = 0; idx < numValidPromotions; idx++) {
      final i = validPromotions[idx];
      final promo = promotions[i];
      
      if (promo.kind == PromotionKind.amountOff || 
          promo.kind == PromotionKind.countOff) {
        // 满减类：t_i <= 1
        final tIndex = numOrders * numValidPromotions + 3 * numValidPromotions + idx;
        if (tIndex < totalVars) {
          upperBounds[tIndex] = 1.0;
        }
      } else if (promo.kind == PromotionKind.eachAmountOff ||
                 promo.kind == PromotionKind.eachCountOff) {
        // 每满减类：t_i <= maxTimes
        final tIndex = numOrders * numValidPromotions + 3 * numValidPromotions + idx;
        if (tIndex < totalVars) {
          upperBounds[tIndex] = (promo.maxTimes ?? 100).toDouble();
        }
      } else if (promo.kind == PromotionKind.amountDiscount ||
                 promo.kind == PromotionKind.countDiscount) {
        // 打折类：z_i <= 1
        final zIndex = numOrders * numValidPromotions + 3 * numValidPromotions + numValidPromotions + discountIdx;
        if (zIndex < totalVars) {
          upperBounds[zIndex] = 1.0;
        }
        discountIdx++;
      }
    }
    
    return LinearProgram(
      optimizationType: OptimizationType.maximize,
      objectiveCoefficients: objective,
      constraintMatrix: constraints,
      constraintRhs: rhs,
      constraintTypes: types,
      integerVariables: integerVars,
      upperBounds: upperBounds,
    );
  }
}

/// 订单数据
class OrderData {
  final String id;
  final List<OrderItem> items;

  OrderData({required this.id, required this.items});
}

/// 订单项
class OrderItem {
  final String ticketTypeId;
  final int quantity;
  final double price;

  OrderItem({
    required this.ticketTypeId,
    required this.quantity,
    required this.price,
  });
}

/// 活动数据
class PromotionData {
  final String id;
  final PromotionKind kind;
  final List<String> scopeTicketTypeIds;
  
  // 门槛
  final double? thresholdAmount;
  final int? thresholdCount;
  final double? stepAmount;
  final int? stepCount;
  
  // 优惠
  final double? discountAmount;
  final double? discountAmountPerStep;
  final double? discountRate;
  
  // 限制
  final int? maxTimes;

  PromotionData({
    required this.id,
    required this.kind,
    required this.scopeTicketTypeIds,
    this.thresholdAmount,
    this.thresholdCount,
    this.stepAmount,
    this.stepCount,
    this.discountAmount,
    this.discountAmountPerStep,
    this.discountRate,
    this.maxTimes,
  });
}

/// 活动类型
enum PromotionKind {
  amountOff,        // 满额立减
  countOff,         // 满件立减
  eachAmountOff,    // 每满额立减
  eachCountOff,     // 每满件立减
  amountDiscount,   // 满额打折
  countDiscount,    // 满件打折
}

