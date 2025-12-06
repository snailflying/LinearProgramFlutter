/// YALPS 主求解函数
/// 
/// 作者: LiuZhiQiang
/// 提供统一的求解接口

import 'types.dart';
import 'tableau.dart';
import 'simplex.dart';
import 'branch_and_cut.dart';
import 'util.dart';

/// 创建解对象表示最优解（如果有）
Solution<VariableKey> createSolution<VariableKey, ConstraintKey>(
  TableauModel<VariableKey, ConstraintKey> tabmod,
  SolutionStatus status,
  double result,
  Options options,
) {
  final precision = options.precision ?? DefaultOptions.precision;
  final includeZeroVariables = options.includeZeroVariables ?? DefaultOptions.includeZeroVariables;
  final tableau = tabmod.tableau;
  final sign = tabmod.sign;
  final vars = tabmod.variables;

  if (status == SolutionStatus.optimal || 
      (status == SolutionStatus.timedout && !result.isNaN)) {
    final variables = <(VariableKey, double)>[];
    for (int i = 0; i < vars.length; i++) {
      final variable = vars[i].key;
      final row = tableau.positionOfVariable[i + 1] - tableau.width;
      final value = row >= 0 ? getIndex(tableau, row, 0) : 0.0;
      if (value > precision) {
        variables.add((variable, roundToPrecision(value, precision)));
      } else if (includeZeroVariables) {
        variables.add((variable, 0.0));
      }
    }
    return Solution(
      status: status,
      result: -sign * result,
      variables: variables,
    );
  } else if (status == SolutionStatus.unbounded) {
    final variable = tableau.variableAtPosition[result.toInt()] - 1;
    return Solution(
      status: SolutionStatus.unbounded,
      result: sign * double.infinity,
      variables: (0 <= variable && variable < vars.length)
          ? [(vars[variable].key, double.infinity)]
          : [],
    );
  } else {
    // infeasible | cycled | (timedout and result is NaN)
    return Solution(
      status: status,
      result: double.nan,
      variables: [],
    );
  }
}

/// 运行求解器求解给定模型，使用给定选项（如果有）
/// 
/// 参见 Model 了解如何指定/创建模型
/// 参见 Options 了解可用的选项类型
/// 参见 Solution 了解返回内容的详细信息
Solution<VariableKey> solve<VariableKey, ConstraintKey>(
  Model<VariableKey, ConstraintKey> model,
  Options? options,
) {
  final tabmod = tableauModel(model);
  final opt = DefaultOptions.merge(options);
  final (status, result) = simplex(tabmod.tableau, opt);

  if (tabmod.integers.isEmpty || status != SolutionStatus.optimal) {
    // 如果是非整数问题，返回单纯形结果
    // 否则，问题有整数变量，但初始解是：
    // 1) unbounded | infeasible => 所有分支也将是 unbounded | infeasible
    // 2) cycled => 无法获得初始解，返回无效解
    return createSolution(tabmod, status, result, opt);
  } else {
    // 整数问题并且找到了最优非整数解
    final (intTabmod, intStatus, intResult) = branchAndCut(tabmod, result, opt);
    return createSolution(intTabmod, intStatus, intResult, opt);
  }
}

