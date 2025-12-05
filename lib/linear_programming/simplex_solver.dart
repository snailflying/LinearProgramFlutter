import 'linear_program.dart';

/// 单纯形法求解器
/// 
/// 实现标准单纯形法求解线性规划问题
class SimplexSolver {
  static const double _epsilon = 1e-10;
  static const int _maxIterations = 10000;

  /// 求解线性规划问题
  static LinearProgramResult solve(LinearProgram problem) {
    // 转换为标准形式
    final standardForm = _convertToStandardForm(problem);
    
    // 寻找初始可行解
    final initialTableau = _createInitialTableau(standardForm);
    
    // 执行单纯形法
    return _simplexMethod(initialTableau, standardForm, problem);
  }

  /// 转换为标准形式（最小化，所有约束为 <=，变量非负）
  static _StandardForm _convertToStandardForm(LinearProgram problem) {
    final numVars = problem.numVariables;
    var numConstraints = problem.numConstraints;
    
    // 处理变量边界约束
    int slackVars = 0;
    int surplusVars = 0;
    int artificialVars = 0;
    
    // 计算需要的松弛变量、剩余变量和人工变量数量
    for (var i = 0; i < numConstraints; i++) {
      switch (problem.constraintTypes[i]) {
        case ConstraintType.lessThanOrEqual:
          slackVars++;
          break;
        case ConstraintType.equal:
          artificialVars++;
          break;
        case ConstraintType.greaterThanOrEqual:
          surplusVars++;
          artificialVars++;
          break;
      }
    }
    
    // 处理变量边界：添加边界约束
    final extendedMatrix = <List<double>>[];
    final extendedRhs = <double>[];
    final extendedTypes = <ConstraintType>[];
    
    // 复制原始约束
    for (var i = 0; i < numConstraints; i++) {
      extendedMatrix.add(List.from(problem.constraintMatrix[i]));
      extendedRhs.add(problem.constraintRhs[i]);
      extendedTypes.add(problem.constraintTypes[i]);
    }
    
    // 添加变量下界约束（x >= lowerBound）
    for (var i = 0; i < numVars; i++) {
      final lower = problem.lowerBounds?[i] ?? 0.0;
      if (lower != 0.0) {
        final boundRow = List<double>.filled(numVars, 0.0);
        boundRow[i] = 1.0;
        extendedMatrix.add(boundRow);
        extendedRhs.add(lower);
        extendedTypes.add(ConstraintType.greaterThanOrEqual);
        numConstraints++;
        surplusVars++;
        artificialVars++;
      }
    }
    
    // 添加变量上界约束（x <= upperBound）
    for (var i = 0; i < numVars; i++) {
      final upper = problem.upperBounds?[i];
      if (upper != null && upper.isFinite) {
        final boundRow = List<double>.filled(numVars, 0.0);
        boundRow[i] = 1.0;
        extendedMatrix.add(boundRow);
        extendedRhs.add(upper);
        extendedTypes.add(ConstraintType.lessThanOrEqual);
        numConstraints++;
        slackVars++;
      }
    }
    
    final totalVars = numVars + slackVars + surplusVars + artificialVars;
    
    // 构建标准形式的目标函数
    final objective = List<double>.filled(totalVars, 0.0);
    for (var i = 0; i < numVars; i++) {
      objective[i] = problem.optimizationType == OptimizationType.maximize
          ? -problem.objectiveCoefficients[i]
          : problem.objectiveCoefficients[i];
    }
    
    // 构建标准形式的约束矩阵
    final matrix = <List<double>>[];
    final rhs = <double>[];
    var slackIdx = numVars;
    var surplusIdx = numVars + slackVars;
    var artificialIdx = numVars + slackVars + surplusVars;
    
    for (var i = 0; i < numConstraints; i++) {
      final row = List<double>.filled(totalVars, 0.0);
      
      // 复制原始约束系数
      for (var j = 0; j < numVars; j++) {
        row[j] = extendedMatrix[i][j];
      }
      
      switch (extendedTypes[i]) {
        case ConstraintType.lessThanOrEqual:
          row[slackIdx++] = 1.0; // 松弛变量
          rhs.add(extendedRhs[i]);
          break;
        case ConstraintType.equal:
          row[artificialIdx++] = 1.0; // 人工变量
          rhs.add(extendedRhs[i]);
          break;
        case ConstraintType.greaterThanOrEqual:
          row[surplusIdx++] = -1.0; // 剩余变量
          row[artificialIdx++] = 1.0; // 人工变量
          rhs.add(extendedRhs[i]);
          break;
      }
      
      matrix.add(row);
    }
    
    return _StandardForm(
      objective: objective,
      matrix: matrix,
      rhs: rhs,
      artificialVarsStart: numVars + slackVars + surplusVars,
      numArtificialVars: artificialVars,
      originalNumVars: numVars,
    );
  }

  /// 创建初始单纯形表
  static _Tableau _createInitialTableau(_StandardForm standardForm) {
    final numRows = standardForm.matrix.length;
    final numCols = standardForm.matrix[0].length;
    
    // 如果有人工变量，使用两阶段法
    if (standardForm.numArtificialVars > 0) {
      return _createTwoPhaseTableau(standardForm);
    }
    
    // 标准单纯形表
    final tableau = List.generate(
      numRows + 1,
      (i) => List<double>.filled(numCols + 1, 0.0),
    );
    
    // 目标函数行（最后一行）
    for (var j = 0; j < numCols; j++) {
      tableau[numRows][j] = -standardForm.objective[j];
    }
    
    // 约束行
    for (var i = 0; i < numRows; i++) {
      for (var j = 0; j < numCols; j++) {
        tableau[i][j] = standardForm.matrix[i][j];
      }
      tableau[i][numCols] = standardForm.rhs[i];
    }
    
    return _Tableau(tableau, List.generate(numRows, (i) => standardForm.originalNumVars + i));
  }

  /// 创建两阶段法的初始表
  static _Tableau _createTwoPhaseTableau(_StandardForm standardForm) {
    final numRows = standardForm.matrix.length;
    final numCols = standardForm.matrix[0].length;
    final artificialStart = standardForm.artificialVarsStart;
    final numArtificial = standardForm.numArtificialVars;
    
    // 第一阶段：最小化人工变量之和
    final phase1Tableau = List.generate(
      numRows + 1,
      (i) => List<double>.filled(numCols + 1, 0.0),
    );
    
    // 第一阶段目标函数：最小化所有人工变量
    for (var j = artificialStart; j < artificialStart + numArtificial; j++) {
      phase1Tableau[numRows][j] = 1.0;
    }
    
    // 约束行
    for (var i = 0; i < numRows; i++) {
      for (var j = 0; j < numCols; j++) {
        phase1Tableau[i][j] = standardForm.matrix[i][j];
      }
      phase1Tableau[i][numCols] = standardForm.rhs[i];
    }
    
    // 更新第一阶段目标函数行（减去包含人工变量的约束行）
    for (var i = 0; i < numRows; i++) {
      if (standardForm.matrix[i].any((val) => 
          val > 0.5 && standardForm.matrix[i].indexOf(val) >= artificialStart)) {
        for (var j = 0; j <= numCols; j++) {
          phase1Tableau[numRows][j] -= phase1Tableau[i][j];
        }
      }
    }
    
    // 找到初始基变量
    // 每个约束行应该有一个基变量（人工变量或松弛变量）
    final basis = <int>[];
    for (var i = 0; i < numRows; i++) {
      var found = false;
      // 首先查找人工变量（系数为1的列）
      for (var j = artificialStart; j < artificialStart + numArtificial; j++) {
        if (phase1Tableau[i][j] > 0.5) {
          basis.add(j);
          found = true;
          break;
        }
      }
      // 如果没有找到人工变量，查找松弛变量
      if (!found) {
        final slackStart = standardForm.originalNumVars;
        for (var j = slackStart; j < artificialStart; j++) {
          if (phase1Tableau[i][j] > 0.5) {
            basis.add(j);
            found = true;
            break;
          }
        }
      }
      // 如果仍然没有找到，查找任何系数为1的列（作为后备）
      if (!found) {
        for (var j = standardForm.originalNumVars; j < numCols; j++) {
          if (phase1Tableau[i][j] > 0.5 && phase1Tableau[i][j] < 1.5) {
            basis.add(j);
            found = true;
            break;
          }
        }
      }
      // 如果还是没有找到，添加一个默认值（不应该发生，但作为安全措施）
      if (!found) {
        // 使用对应的人工变量索引
        final artificialIdx = artificialStart + (basis.length % numArtificial);
        if (artificialIdx < artificialStart + numArtificial) {
          basis.add(artificialIdx);
        } else {
          // 最后的后备：使用第一个可用的人工变量
          basis.add(artificialStart);
        }
      }
    }
    
    // 确保基变量列表长度等于约束行数
    assert(basis.length == numRows, '基变量数量(${basis.length})必须等于约束行数($numRows)');
    
    return _Tableau(phase1Tableau, basis);
  }

  /// 执行单纯形法
  static LinearProgramResult _simplexMethod(
    _Tableau tableau,
    _StandardForm standardForm,
    LinearProgram originalProblem,
  ) {
    // 如果有人工变量，先执行第一阶段
    if (standardForm.numArtificialVars > 0) {
      final phase1Result = _phase1(tableau, standardForm);
      if (!phase1Result.isOptimal || phase1Result.optimalValue! > _epsilon) {
        return LinearProgramResult.infeasible(
          message: '第一阶段求解失败，无可行解',
        );
      }
      // 移除人工变量，进入第二阶段
      tableau = _removeArtificialVars(tableau, standardForm);
    }
    
    // 第二阶段：求解原始问题
    return _phase2(tableau, standardForm, originalProblem);
  }

  /// 第一阶段：消除人工变量
  static LinearProgramResult _phase1(_Tableau tableau, _StandardForm standardForm) {
    var iteration = 0;
    
    while (iteration < _maxIterations) {
      // 检查是否最优
      if (_isOptimal(tableau)) {
        final optimalValue = tableau.tableau[tableau.tableau.length - 1][tableau.tableau[0].length - 1];
        return LinearProgramResult.optimal(
          optimalValue: optimalValue,
          solution: _extractSolution(tableau, standardForm),
        );
      }
      
      // 选择入基变量（最小负值）
      final pivotCol = _findPivotColumn(tableau);
      if (pivotCol == -1) {
        return LinearProgramResult.unbounded();
      }
      
      // 选择出基变量
      final pivotRow = _findPivotRow(tableau, pivotCol);
      if (pivotRow == -1) {
        return LinearProgramResult.unbounded();
      }
      
      // 执行主元操作
      _pivot(tableau, pivotRow, pivotCol);
      
      iteration++;
    }
    
    return LinearProgramResult.unsolved(message: '达到最大迭代次数');
  }

  /// 第二阶段：求解原始问题
  static LinearProgramResult _phase2(
    _Tableau tableau,
    _StandardForm standardForm,
    LinearProgram originalProblem,
  ) {
    final numRows = tableau.tableau.length - 1;
    final numCols = tableau.tableau[0].length - 1;
    
    // 确保基变量列表长度正确
    List<int> basis = List.from(tableau.basis);
    if (basis.length != numRows) {
      // 如果基变量列表长度不匹配，尝试修复
      while (basis.length < numRows) {
        basis.add(basis.length);
      }
      if (basis.length > numRows) {
        basis = basis.sublist(0, numRows);
      }
      // 创建新的 tableau 对象
      tableau = _Tableau(tableau.tableau, basis);
    }
    
    // 更新目标函数行
    for (var j = 0; j < numCols; j++) {
      tableau.tableau[numRows][j] = -standardForm.objective[j];
    }
    
    // 重新计算目标函数行（减去基变量列）
    for (var i = 0; i < numRows && i < tableau.basis.length; i++) {
      final basisVar = tableau.basis[i];
      if (basisVar < standardForm.originalNumVars && basisVar >= 0) {
        final coeff = standardForm.objective[basisVar];
        for (var j = 0; j <= numCols; j++) {
          tableau.tableau[numRows][j] += coeff * tableau.tableau[i][j];
        }
      }
    }
    
    var iteration = 0;
    
    while (iteration < _maxIterations) {
      // 检查是否最优
      if (_isOptimal(tableau)) {
        final optimalValue = tableau.tableau[numRows][numCols];
        final solution = _extractSolution(tableau, standardForm);
        
        // 如果是最大化问题，需要取负
        final finalValue = originalProblem.optimizationType == OptimizationType.maximize
            ? -optimalValue
            : optimalValue;
        
        return LinearProgramResult.optimal(
          optimalValue: finalValue,
          solution: solution,
        );
      }
      
      // 选择入基变量
      final pivotCol = _findPivotColumn(tableau);
      if (pivotCol == -1) {
        return LinearProgramResult.unbounded();
      }
      
      // 选择出基变量
      final pivotRow = _findPivotRow(tableau, pivotCol);
      if (pivotRow == -1) {
        return LinearProgramResult.unbounded();
      }
      
      // 执行主元操作
      _pivot(tableau, pivotRow, pivotCol);
      
      iteration++;
    }
    
    return LinearProgramResult.unsolved(message: '达到最大迭代次数');
  }

  /// 检查是否达到最优
  static bool _isOptimal(_Tableau tableau) {
    final lastRow = tableau.tableau.last;
    for (var j = 0; j < lastRow.length - 1; j++) {
      if (lastRow[j] < -_epsilon) {
        return false;
      }
    }
    return true;
  }

  /// 找到主元列（入基变量）
  static int _findPivotColumn(_Tableau tableau) {
    final lastRow = tableau.tableau.last;
    var minVal = 0.0;
    var pivotCol = -1;
    
    for (var j = 0; j < lastRow.length - 1; j++) {
      if (lastRow[j] < minVal - _epsilon) {
        minVal = lastRow[j];
        pivotCol = j;
      }
    }
    
    return pivotCol;
  }

  /// 找到主元行（出基变量）
  static int _findPivotRow(_Tableau tableau, int pivotCol) {
    var minRatio = double.infinity;
    var pivotRow = -1;
    
    for (var i = 0; i < tableau.tableau.length - 1; i++) {
      final pivotElement = tableau.tableau[i][pivotCol];
      if (pivotElement > _epsilon) {
        final rhs = tableau.tableau[i][tableau.tableau[0].length - 1];
        final ratio = rhs / pivotElement;
        if (ratio >= 0 && ratio < minRatio) {
          minRatio = ratio;
          pivotRow = i;
        }
      }
    }
    
    return pivotRow;
  }

  /// 执行主元操作
  static void _pivot(_Tableau tableau, int pivotRow, int pivotCol) {
    final pivotElement = tableau.tableau[pivotRow][pivotCol];
    
    // 更新基变量
    tableau.basis[pivotRow] = pivotCol;
    
    // 标准化主元行
    for (var j = 0; j < tableau.tableau[0].length; j++) {
      tableau.tableau[pivotRow][j] /= pivotElement;
    }
    
    // 消元
    for (var i = 0; i < tableau.tableau.length; i++) {
      if (i != pivotRow) {
        final factor = tableau.tableau[i][pivotCol];
        for (var j = 0; j < tableau.tableau[0].length; j++) {
          tableau.tableau[i][j] -= factor * tableau.tableau[pivotRow][j];
        }
      }
    }
  }

  /// 提取解向量
  static List<double> _extractSolution(_Tableau tableau, _StandardForm standardForm) {
    final solution = List<double>.filled(standardForm.originalNumVars, 0.0);
    
    for (var i = 0; i < tableau.basis.length; i++) {
      final varIdx = tableau.basis[i];
      if (varIdx < standardForm.originalNumVars) {
        final rhsIdx = tableau.tableau[0].length - 1;
        solution[varIdx] = tableau.tableau[i][rhsIdx];
      }
    }
    
    return solution;
  }

  /// 移除人工变量
  static _Tableau _removeArtificialVars(_Tableau tableau, _StandardForm standardForm) {
    final artificialStart = standardForm.artificialVarsStart;
    final numArtificial = standardForm.numArtificialVars;
    final numRows = tableau.tableau.length - 1;
    
    // 移除人工变量列
    final newTableau = tableau.tableau.map((row) {
      final newRow = <double>[];
      for (var j = 0; j < row.length; j++) {
        if (j < artificialStart || j >= artificialStart + numArtificial) {
          newRow.add(row[j]);
        }
      }
      return newRow;
    }).toList();
    
    // 更新基变量索引
    final newBasis = <int>[];
    for (var i = 0; i < tableau.basis.length && i < numRows; i++) {
      final idx = tableau.basis[i];
      if (idx >= artificialStart + numArtificial) {
        // 人工变量之后的变量，索引需要减去人工变量数量
        newBasis.add(idx - numArtificial);
      } else if (idx >= artificialStart) {
        // 人工变量仍在基中，这不应该发生（第一阶段应该已经移除）
        // 尝试找到一个替代的基变量（松弛变量）
        var found = false;
        // 在新的 tableau 中，人工变量列已被移除，所以松弛变量的索引不变
        for (var j = standardForm.originalNumVars; j < artificialStart; j++) {
          // 在新 tableau 中，列 j 的索引就是 j（因为人工变量列已被移除）
          if (j < newTableau[0].length - 1 && newTableau[i][j] > 0.5) {
            newBasis.add(j);
            found = true;
            break;
          }
        }
        if (!found) {
          // 如果找不到，使用第一个非零列
          for (var j = 0; j < newTableau[0].length - 1; j++) {
            if (newTableau[i][j].abs() > _epsilon) {
              newBasis.add(j);
              found = true;
              break;
            }
          }
        }
        if (!found) {
          // 最后的后备：使用0（表示该行可能是冗余的）
          newBasis.add(0);
        }
      } else {
        // 原始变量或松弛变量，索引不变
        newBasis.add(idx);
      }
    }
    
    // 确保基变量列表长度正确
    while (newBasis.length < numRows) {
      newBasis.add(0);
    }
    
    return _Tableau(newTableau, newBasis);
  }
}

/// 标准形式
class _StandardForm {
  final List<double> objective;
  final List<List<double>> matrix;
  final List<double> rhs;
  final int artificialVarsStart;
  final int numArtificialVars;
  final int originalNumVars;

  _StandardForm({
    required this.objective,
    required this.matrix,
    required this.rhs,
    required this.artificialVarsStart,
    required this.numArtificialVars,
    required this.originalNumVars,
  });
}

/// 单纯形表
class _Tableau {
  final List<List<double>> tableau;
  final List<int> basis;

  _Tableau(this.tableau, this.basis);
}

