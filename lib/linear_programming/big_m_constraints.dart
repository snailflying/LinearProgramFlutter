import 'linear_program.dart';

/// Big-M约束构建器
/// 
/// 用于处理打折类活动的条件逻辑线性化
class BigMConstraints {
  /// 为打折类活动构建Big-M约束
  /// 
  /// 打折类活动的逻辑：
  /// - 如果满足门槛（B_i >= T_i）：D_i = (1-r_i) * A_i
  /// - 如果不满足门槛：D_i = 0
  /// 
  /// 使用二元变量z_i表示是否触发，Big-M方法线性化：
  /// 1. B_i >= T_i * z_i (门槛约束)
  /// 2. D_i <= (1-r_i) * A_i (上界)
  /// 3. D_i >= (1-r_i) * A_i - (1-r_i) * M * (1-z_i) (下界，当z_i=1时)
  /// 4. D_i <= (1-r_i) * M * z_i (gating，当z_i=0时强制D_i=0)
  /// 
  /// 参数：
  /// - [aIndex]: A_i变量的索引
  /// - [cIndex]: C_i变量的索引（如果使用件数门槛）
  /// - [dIndex]: D_i变量的索引
  /// - [zIndex]: z_i变量的索引（需要是整数变量）
  /// - [threshold]: 门槛值T_i
  /// - [discountRate]: 折扣率r_i
  /// - [bigM]: Big-M常数（通常取sum_o a_{o,i}）
  /// - [useAmount]: 是否使用金额门槛（true）还是件数门槛（false）
  /// - [totalVars]: 总变量数
  /// 
  /// 返回：约束列表，每个约束是一个Map，包含matrix行、rhs、type
  static List<Map<String, dynamic>> buildDiscountConstraints({
    required int aIndex,
    required int cIndex,
    required int dIndex,
    required int zIndex,
    required double threshold,
    required double discountRate,
    required double bigM,
    required bool useAmount,
    required int totalVars,
  }) {
    final constraints = <Map<String, dynamic>>[];
    final alpha = 1.0 - discountRate; // 优惠比例
    
    // 1. 门槛约束：B_i >= T_i * z_i
    final thresholdRow = List<double>.filled(totalVars, 0.0);
    if (useAmount) {
      thresholdRow[aIndex] = 1.0; // A_i
    } else {
      thresholdRow[cIndex] = 1.0; // C_i
    }
    thresholdRow[zIndex] = -threshold; // -T_i * z_i
    constraints.add({
      'matrix': thresholdRow,
      'rhs': 0.0,
      'type': ConstraintType.greaterThanOrEqual,
    });
    
    // 2. 上界：D_i <= alpha * A_i
    final upperRow = List<double>.filled(totalVars, 0.0);
    upperRow[dIndex] = 1.0; // D_i
    upperRow[aIndex] = -alpha; // -alpha * A_i
    constraints.add({
      'matrix': upperRow,
      'rhs': 0.0,
      'type': ConstraintType.lessThanOrEqual,
    });
    
    // 3. 下界：D_i >= alpha * A_i - alpha * M * (1-z_i)
    // 展开：D_i >= alpha * A_i - alpha * M + alpha * M * z_i
    // 移项：D_i - alpha * A_i - alpha * M * z_i >= -alpha * M
    final lowerRow = List<double>.filled(totalVars, 0.0);
    lowerRow[dIndex] = 1.0; // D_i
    lowerRow[aIndex] = -alpha; // -alpha * A_i
    lowerRow[zIndex] = -alpha * bigM; // -alpha * M * z_i (修正符号)
    constraints.add({
      'matrix': lowerRow,
      'rhs': -alpha * bigM, // -alpha * M
      'type': ConstraintType.greaterThanOrEqual,
    });
    
    // 4. Gating：D_i <= alpha * M * z_i
    final gatingRow = List<double>.filled(totalVars, 0.0);
    gatingRow[dIndex] = 1.0; // D_i
    gatingRow[zIndex] = -alpha * bigM; // -alpha * M * z_i
    constraints.add({
      'matrix': gatingRow,
      'rhs': 0.0,
      'type': ConstraintType.lessThanOrEqual,
    });
    
    // 5. 非负性：D_i >= 0（通常已经在变量定义中处理）
    
    return constraints;
  }
}

