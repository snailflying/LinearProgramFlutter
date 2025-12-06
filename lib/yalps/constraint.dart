/// 约束辅助函数
/// 
/// 作者: LiuZhiQiang
/// 提供便捷的约束创建函数

import 'types.dart';

/// 返回一个指定某物应该小于等于 value 的约束
/// 等价于 Constraint(max: value)
Constraint lessEq(double value) {
  return Constraint(max: value);
}

/// 返回一个指定某物应该大于等于 value 的约束
/// 等价于 Constraint(min: value)
Constraint greaterEq(double value) {
  return Constraint(min: value);
}

/// 返回一个指定某物应该完全等于 value 的约束
/// 等价于 Constraint(equal: value)
Constraint equalTo(double value) {
  return Constraint(equal: value);
}

/// 返回一个指定某物应该在 lower 和 upper 之间（都包含）的约束
/// 等价于 Constraint(min: lower, max: upper)
Constraint inRange(double lower, double upper) {
  return Constraint(min: lower, max: upper);
}

