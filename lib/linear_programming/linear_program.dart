/// 线性规划问题模型
/// 
/// 支持标准形式的线性规划问题：
/// - 最大化或最小化目标函数
/// - 等式和不等式约束（<=, =, >=）
/// - 变量上下界
/// - 整数变量约束
class LinearProgram {
  /// 目标函数类型
  final OptimizationType optimizationType;
  
  /// 目标函数系数向量 (c^T x)
  final List<double> objectiveCoefficients;
  
  /// 约束矩阵 A (A x <=/=/>= b)
  final List<List<double>> constraintMatrix;
  
  /// 约束右端项向量 b
  final List<double> constraintRhs;
  
  /// 约束类型列表（对应每个约束）
  final List<ConstraintType> constraintTypes;
  
  /// 变量下界（可选，默认为0）
  final List<double>? lowerBounds;
  
  /// 变量上界（可选，无界时为null）
  final List<double>? upperBounds;
  
  /// 整数变量索引集合（空集合表示连续线性规划）
  final Set<int> integerVariables;

  LinearProgram({
    required this.optimizationType,
    required this.objectiveCoefficients,
    required this.constraintMatrix,
    required this.constraintRhs,
    required this.constraintTypes,
    this.lowerBounds,
    this.upperBounds,
    Set<int>? integerVariables,
  })  : integerVariables = integerVariables ?? {},
        assert(objectiveCoefficients.isNotEmpty, '目标函数系数不能为空'),
        assert(constraintMatrix.length == constraintRhs.length,
            '约束矩阵行数必须等于右端项数量'),
        assert(constraintMatrix.length == constraintTypes.length,
            '约束矩阵行数必须等于约束类型数量'),
        assert(constraintMatrix.every((row) => row.length == objectiveCoefficients.length),
            '约束矩阵每行长度必须等于变量数量'),
        assert(lowerBounds == null || lowerBounds.length == objectiveCoefficients.length,
            '下界数量必须等于变量数量'),
        assert(upperBounds == null || upperBounds.length == objectiveCoefficients.length,
            '上界数量必须等于变量数量'),
        assert(integerVariables == null || integerVariables.every((i) => i >= 0 && i < objectiveCoefficients.length),
            '整数变量索引必须在有效范围内');

  /// 变量数量
  int get numVariables => objectiveCoefficients.length;

  /// 约束数量
  int get numConstraints => constraintMatrix.length;

  /// 是否为整数规划问题
  bool get isIntegerProgram => integerVariables.isNotEmpty;
}

/// 优化类型
enum OptimizationType {
  /// 最大化
  maximize,
  /// 最小化
  minimize,
}

/// 约束类型
enum ConstraintType {
  /// 小于等于 <=
  lessThanOrEqual,
  /// 等于 =
  equal,
  /// 大于等于 >=
  greaterThanOrEqual,
}

/// 线性规划求解结果
class LinearProgramResult {
  /// 是否找到最优解
  final bool isOptimal;
  
  /// 最优值
  final double? optimalValue;
  
  /// 最优解向量
  final List<double>? solution;
  
  /// 求解状态
  final SolutionStatus status;
  
  /// 求解消息
  final String message;

  LinearProgramResult({
    required this.isOptimal,
    this.optimalValue,
    this.solution,
    required this.status,
    this.message = '',
  });

  /// 创建最优解结果
  factory LinearProgramResult.optimal({
    required double optimalValue,
    required List<double> solution,
    String message = '找到最优解',
  }) {
    return LinearProgramResult(
      isOptimal: true,
      optimalValue: optimalValue,
      solution: solution,
      status: SolutionStatus.optimal,
      message: message,
    );
  }

  /// 创建无可行解结果
  factory LinearProgramResult.infeasible({String message = '无可行解'}) {
    return LinearProgramResult(
      isOptimal: false,
      status: SolutionStatus.infeasible,
      message: message,
    );
  }

  /// 创建无界解结果
  factory LinearProgramResult.unbounded({String message = '问题无界'}) {
    return LinearProgramResult(
      isOptimal: false,
      status: SolutionStatus.unbounded,
      message: message,
    );
  }

  /// 创建未求解结果
  factory LinearProgramResult.unsolved({String message = '未求解'}) {
    return LinearProgramResult(
      isOptimal: false,
      status: SolutionStatus.unsolved,
      message: message,
    );
  }
}

/// 求解状态
enum SolutionStatus {
  /// 找到最优解
  optimal,
  /// 无可行解
  infeasible,
  /// 无界
  unbounded,
  /// 未求解
  unsolved,
}

