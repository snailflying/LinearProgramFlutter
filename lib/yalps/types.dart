/// YALPS 类型定义
/// 
/// 作者: LiuZhiQiang
/// 基于 YALPS (Yet Another Linear Programming Solver) 的 Dart 实现

/// 约束边界定义
/// 
/// 指定某个值的总和应该满足的边界条件
class Constraint {
  /// 应该等于这个值
  /// 如果同时定义了 min 或 max，则使用 equal
  final double? equal;

  /// 应该大于等于这个值
  /// 可以与 max 同时指定
  final double? min;

  /// 应该小于等于这个值
  /// 可以与 min 同时指定
  final double? max;

  const Constraint({
    this.equal,
    this.min,
    this.max,
  });
}

/// 变量的系数
/// 
/// 可以表示为 Map 或 List<[String, double]> 的 Iterable
typedef Coefficients<ConstraintKey> = 
    Map<ConstraintKey, double>;

/// 优化方向
enum OptimizationDirection {
  /// 最大化
  maximize,
  /// 最小化
  minimize,
}

/// 线性规划模型
/// 
/// constraints, variables 和每个变量的系数可以是 Map 或 Iterable
/// 模型被求解器视为只读（递归），不会被修改
class Model<VariableKey, ConstraintKey> {
  /// 指示是最大化还是最小化目标
  /// 如果为空，默认为 maximize
  final OptimizationDirection? direction;

  /// 要优化的值的键
  /// 可以省略，在这种情况下求解器给出满足约束的某个解（如果有）
  final ConstraintKey? objective;

  /// 表示问题约束的 Map 或 Iterable
  /// 如果是 Iterable，重复的键不会被忽略，而是合并为最严格的边界
  final dynamic constraints;

  /// 表示问题变量的 Map 或 Iterable
  /// 如果是 Iterable，重复的键不会被忽略
  /// 变量的顺序在解中保留，但默认情况下值为 0 的变量不包含在解中
  final dynamic variables;

  /// 指示对应变量为整数的变量键的 Iterable
  /// 建议使用 Set 作为 Iterable
  /// 也可以是 boolean，指示所有变量是否为整数
  /// 如果为空，则所有变量被视为非整数
  final dynamic integers;

  /// 指示对应变量为二进制（在解中只能为 0 或 1）的变量键的 Iterable
  /// 建议使用 Set 作为 Iterable
  /// 也可以是 boolean，指示所有变量是否为二进制
  /// 如果为空，则所有变量被视为非二进制
  final dynamic binaries;

  const Model({
    this.direction,
    this.objective,
    required this.constraints,
    required this.variables,
    this.integers,
    this.binaries,
  });
}

/// 解的状态类型
enum SolutionStatus {
  /// 找到最优解
  optimal,
  /// 无可行解
  infeasible,
  /// 无界
  unbounded,
  /// 超时
  timedout,
  /// 循环
  cycled,
}

/// 求解器返回的解对象
class Solution<VariableKey> {
  /// 状态指示求解器能够找到什么类型的解（如果有）
  /// 
  /// - optimal: 一切正常，求解器找到了最优解
  /// - infeasible: 问题没有可能的解，result 将为 NaN
  /// - unbounded: 变量或变量组合没有充分约束，result 将为 +-Infinity
  /// - timedout: 求解器提前退出整数问题，可能返回当前次优解
  /// - cycled: 单纯形法循环并退出，result 将为 NaN
  final SolutionStatus status;

  /// 目标的最终最大化或最小化值
  /// 如果 status 是 infeasible, cycled 或 timedout，可能为 NaN
  /// 如果 status 是 unbounded，可能为 +-Infinity
  final double result;

  /// 变量及其系数的数组，这些变量加起来等于 result 同时满足问题的约束
  /// 默认情况下，系数为 0 的变量不包含在此中
  /// 如果 status 是 unbounded，variables 可能包含一个变量，这是求解器恰好结束时的无界变量
  final List<(VariableKey, double)> variables;

  Solution({
    required this.status,
    required this.result,
    required this.variables,
  });
}

/// 求解器选项
class Options {
  /// 数量级等于或小于提供的精度的数字被视为零
  /// 同样，精度决定数字是否足够整数
  /// 默认值为 1e-8
  final double? precision;

  /// 在极少数情况下，求解器可能会循环
  /// 当枢轴数超过 maxPivots 时，假定是这种情况
  /// 设置为 true 将导致求解器显式检查循环，如果找到循环则提前停止
  /// 注意检查循环可能会产生小的性能开销
  /// 默认值为 false
  final bool? checkCycles;

  /// 这决定了单纯形法内允许的最大枢轴数
  /// 如果超过此值，则假定单纯形法循环，返回的解将具有 "cycled" 状态
  /// 如果问题非常大，可能需要将此选项设置得更高
  /// 默认值为 8192
  final int? maxPivots;

  /// 此选项仅适用于整数问题
  /// 如果在 (1 +- tolerance) * {问题的非整数解} 内找到整数解，
  /// 则返回此近似整数解
  /// 例如，0.05 的容差将返回在非整数解的 5% 内找到的第一个整数解
  /// 此选项对于大型整数问题很有帮助，其中最优解变得更难找到，
  /// 但近似或接近最优的解可能更容易找到
  /// 默认值为 0（仅找到最优解）
  final double? tolerance;

  /// 此选项仅适用于整数问题
  /// 它指定主分支定界部分在超时之前可能花费的最大时间（以毫秒为单位）
  /// 如果发生超时，返回的解将具有 "timedout" 状态
  /// 此外，如果在超时之前找到任何次优解，则也会返回
  /// 默认值为 Infinity（无超时）
  final double? timeout;

  /// 此选项仅适用于整数问题
  /// 它确定主分支定界算法的最大迭代次数
  /// 可以与 timeout 一起使用或代替 timeout 来防止求解器花费太长时间
  /// 默认值为 32768
  final int? maxIterations;

  /// 控制最终值为 0 的变量是否应包含在结果 Solution 的 variables 中
  /// 默认值为 false
  final bool? includeZeroVariables;

  const Options({
    this.precision,
    this.checkCycles,
    this.maxPivots,
    this.tolerance,
    this.timeout,
    this.maxIterations,
    this.includeZeroVariables,
  });
}

/// 默认选项值
class DefaultOptions {
  static const double precision = 1e-8;
  static const bool checkCycles = false;
  static const int maxPivots = 8192;
  static const double tolerance = 0.0;
  static const double timeout = double.infinity;
  static const int maxIterations = 32768;
  static const bool includeZeroVariables = false;

  /// 创建完整的默认选项
  static Options create() {
    return const Options(
      precision: precision,
      checkCycles: checkCycles,
      maxPivots: maxPivots,
      tolerance: tolerance,
      timeout: timeout,
      maxIterations: maxIterations,
      includeZeroVariables: includeZeroVariables,
    );
  }

  /// 合并用户选项和默认选项
  static Options merge(Options? userOptions) {
    if (userOptions == null) {
      return create();
    }
    return Options(
      precision: userOptions.precision ?? precision,
      checkCycles: userOptions.checkCycles ?? checkCycles,
      maxPivots: userOptions.maxPivots ?? maxPivots,
      tolerance: userOptions.tolerance ?? tolerance,
      timeout: userOptions.timeout ?? timeout,
      maxIterations: userOptions.maxIterations ?? maxIterations,
      includeZeroVariables: userOptions.includeZeroVariables ?? includeZeroVariables,
    );
  }
}

