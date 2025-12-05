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
    // 标准形式要求所有约束都是 <= 形式
    final matrix = <List<double>>[];
    final rhs = <double>[];
    var slackIdx = numVars;
    var surplusIdx = numVars + slackVars;
    var artificialIdx = numVars + slackVars + surplusVars;

    for (var i = 0; i < numConstraints; i++) {
      final row = List<double>.filled(totalVars, 0.0);

      switch (extendedTypes[i]) {
        case ConstraintType.lessThanOrEqual:
          // x <= b 保持不变
          for (var j = 0; j < numVars; j++) {
            row[j] = extendedMatrix[i][j];
          }
          row[slackIdx++] = 1.0; // 松弛变量
          rhs.add(extendedRhs[i]);
          break;
        case ConstraintType.equal:
          // x = b 保持不变
          for (var j = 0; j < numVars; j++) {
            row[j] = extendedMatrix[i][j];
          }
          row[artificialIdx++] = 1.0; // 人工变量
          rhs.add(extendedRhs[i]);
          break;
        case ConstraintType.greaterThanOrEqual:
          // x >= b 转换为 -x <= -b
          // 然后添加剩余变量 s 和人工变量 a：-x - s + a = -b
          // 其中 s >= 0, a >= 0
          for (var j = 0; j < numVars; j++) {
            row[j] = -extendedMatrix[i][j]; // 系数取负
          }
          row[surplusIdx++] = -1.0; // 剩余变量 s（系数为-1）
          row[artificialIdx++] = 1.0; // 人工变量 a（系数为1）
          rhs.add(-extendedRhs[i]); // RHS取负
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

    return _Tableau(
      tableau,
      List.generate(numRows, (i) => standardForm.originalNumVars + i),
    );
  }

  /// 创建两阶段法的初始表
  static _Tableau _createTwoPhaseTableau(_StandardForm standardForm) {
    final numRows = standardForm.matrix.length;
    final numCols = standardForm.matrix[0].length;
    final artificialStart = standardForm.artificialVarsStart;
    final numArtificial = standardForm.numArtificialVars;

    // 第一阶段：最小化人工变量之和
    // 在标准形式中，最小化 -w = -sum(人工变量)
    // 即目标行存储 -c，最小化 c^T x
    final phase1Tableau = List.generate(
      numRows + 1,
      (i) => List<double>.filled(numCols + 1, 0.0),
    );

    // 约束行
    for (var i = 0; i < numRows; i++) {
      for (var j = 0; j < numCols; j++) {
        phase1Tableau[i][j] = standardForm.matrix[i][j];
      }
      phase1Tableau[i][numCols] = standardForm.rhs[i];
    }

    // 第一阶段目标函数：最小化所有人工变量
    // 先设置人工变量的系数为-1（因为目标行存储-c）
    for (var j = artificialStart; j < artificialStart + numArtificial; j++) {
      phase1Tableau[numRows][j] = -1.0;
    }

    // 更新第一阶段目标函数行（消除基变量的贡献）
    // 对于每行包含人工变量的约束，加上该行
    for (var i = 0; i < numRows; i++) {
      // 检查该行是否有人工变量作为基变量
      for (var j = artificialStart; j < artificialStart + numArtificial; j++) {
        if (standardForm.matrix[i][j].abs() > 0.5) {
          // 这一行有人工变量，需要消除其在目标行的贡献
          // 目标行 = 目标行 + 约束行
          for (var k = 0; k <= numCols; k++) {
            phase1Tableau[numRows][k] += phase1Tableau[i][k];
          }
          break;
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
    final debug = const bool.fromEnvironment(
      'DEBUG_SIMPLEX',
      defaultValue: false,
    );

    // 如果有人工变量，先执行第一阶段
    if (standardForm.numArtificialVars > 0) {
      final phase1Result = _phase1(tableau, standardForm, debug: debug);
      if (!phase1Result.isOptimal || phase1Result.optimalValue! > _epsilon) {
        if (debug) {
          print(
            '第一阶段求解失败：isOptimal=${phase1Result.isOptimal}, optimalValue=${phase1Result.optimalValue}',
          );
        }
        return LinearProgramResult.infeasible(message: '第一阶段求解失败，无可行解');
      }
      // 移除人工变量，进入第二阶段
      tableau = _removeArtificialVars(tableau, standardForm);
    }

    // 第二阶段：求解原始问题
    return _phase2(tableau, standardForm, originalProblem, debug: debug);
  }

  /// 第一阶段：消除人工变量
  static LinearProgramResult _phase1(
    _Tableau tableau,
    _StandardForm standardForm, {
    bool debug = false,
  }) {
    var iteration = 0;
    final artificialStart = standardForm.artificialVarsStart;
    final numArtificial = standardForm.numArtificialVars;
    final artificialEnd = artificialStart + numArtificial;

    if (debug) {
      print('=== 第一阶段求解开始 ===');
      print('初始基变量: ${tableau.basis}');
      print('初始目标函数行: ${tableau.tableau.last}');
      print('初始目标函数值: ${tableau.tableau.last.last}');
      print('artificialStart: $artificialStart');
      print('numArtificial: $numArtificial');
      print('originalNumVars: ${standardForm.originalNumVars}');
    }

    while (iteration < _maxIterations) {
      if (debug && iteration < 5) {
        print('\n--- 迭代 $iteration ---');
        print('基变量: ${tableau.basis}');
        print('目标函数行: ${tableau.tableau.last}');
        print('目标函数值: ${tableau.tableau.last.last}');
      }

      // 检查目标函数值是否为0
      final rawValue = tableau.tableau.last.last;
      final optimalValue = -rawValue;

      if (optimalValue.abs() < _epsilon) {
        // 检查是否还有人工变量在基中
        bool hasArtificialInBasis = false;
        for (final basisVar in tableau.basis) {
          if (basisVar >= artificialStart && basisVar < artificialEnd) {
            hasArtificialInBasis = true;
            break;
          }
        }

        if (!hasArtificialInBasis) {
          // 目标函数值为0且无人工变量在基中
          if (debug) {
            print('\n=== 第一阶段求解完成（目标函数值为0，无人工变量）===');
            print('迭代次数: $iteration');
            print('最优值: $optimalValue');
            print('基变量: ${tableau.basis}');
          }
          return LinearProgramResult.optimal(
            optimalValue: optimalValue,
            solution:
                _extractSolution(tableau, standardForm, debug: debug) ?? [],
          );
        } else if (debug) {
          print('警告：目标函数值为0，但基变量中仍有人工变量，尝试移除');
          // 尝试用非人工变量替换人工变量
          for (var i = 0; i < tableau.basis.length; i++) {
            final basisVar = tableau.basis[i];
            if (basisVar >= artificialStart && basisVar < artificialEnd) {
              // 找到可以替换的非人工变量
              for (var j = 0; j < standardForm.originalNumVars; j++) {
                if (!tableau.basis.contains(j) &&
                    tableau.tableau[i][j].abs() > _epsilon) {
                  print('移除人工变量$basisVar：用变量$j替换（行$i）');
                  _pivot(tableau, i, j);
                  break;
                }
              }
            }
          }
        }
      }

      // 选择入基变量
      final pivotCol = _findPivotColumn(tableau);
      if (pivotCol == -1) {
        // 无法改进，检查是否最优
        final lastRow = tableau.tableau.last;
        final currentOptimal = -lastRow[lastRow.length - 1];
        if (debug) {
          print('\n=== 第一阶段求解完成（通过pivotCol == -1）===');
          print('迭代次数: $iteration');
          print('最优值: $currentOptimal');
        }
        return LinearProgramResult.optimal(
          optimalValue: currentOptimal,
          solution: _extractSolution(tableau, standardForm, debug: debug) ?? [],
        );
      }

      if (debug && iteration < 5) {
        print('入基变量: $pivotCol');
      }

      // 选择出基变量（优先选择人工变量，但必须满足最小比值条件）
      var pivotRow = -1;
      var minRatio = double.infinity;
      var artificialPivotRow = -1;
      var artificialMinRatio = double.infinity;

      for (var i = 0; i < tableau.tableau.length - 1; i++) {
        final pivotElement = tableau.tableau[i][pivotCol];
        if (pivotElement.abs() > _epsilon) {
          final rhs = tableau.tableau[i][tableau.tableau[0].length - 1];
          double? ratio;
          if (pivotElement > _epsilon && rhs >= -_epsilon) {
            ratio = rhs / pivotElement;
          } else if (pivotElement < -_epsilon && rhs <= _epsilon) {
            ratio = rhs / pivotElement;
          }

          if (ratio != null && ratio >= 0) {
            // 更新全局最小比值
            if (ratio < minRatio - _epsilon) {
              minRatio = ratio;
              pivotRow = i;
            } else if ((ratio - minRatio).abs() < _epsilon && i < pivotRow) {
              pivotRow = i;
            }

            // 检查人工变量
            final basisVar = tableau.basis[i];
            if (basisVar >= artificialStart && basisVar < artificialEnd) {
              if (ratio < artificialMinRatio - _epsilon) {
                artificialMinRatio = ratio;
                artificialPivotRow = i;
              } else if ((ratio - artificialMinRatio).abs() < _epsilon &&
                  i < artificialPivotRow) {
                artificialPivotRow = i;
              }
            }
          }
        }
      }

      // 只有当人工变量的比值等于全局最小比值时，才优先选择人工变量
      if (artificialPivotRow != -1 &&
          (artificialMinRatio - minRatio).abs() < _epsilon) {
        pivotRow = artificialPivotRow;
      }

      if (pivotRow == -1) {
        if (debug) {
          print('警告：找不到出基变量，返回无界');
        }
        return LinearProgramResult.unbounded();
      }

      if (debug && iteration < 5) {
        print('出基变量: ${tableau.basis[pivotRow]} (行 $pivotRow)');
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
    LinearProgram originalProblem, {
    bool debug = false,
  }) {
    final numRows = tableau.tableau.length - 1;
    final numCols = tableau.tableau[0].length - 1;
    final isMaximize =
        originalProblem.optimizationType == OptimizationType.maximize;

    // 确保基变量列表长度正确
    List<int> basis = List.from(tableau.basis);
    if (basis.length != numRows) {
      while (basis.length < numRows) {
        basis.add(basis.length);
      }
      if (basis.length > numRows) {
        basis = basis.sublist(0, numRows);
      }
      tableau = _Tableau(tableau.tableau, basis);
    }

    if (debug) {
      print('\n=== 第二阶段求解开始 ===');
      print('基变量: ${tableau.basis}');
      print(
        'tableau大小: ${tableau.tableau.length} x ${tableau.tableau[0].length}',
      );
      print('原始变量数: ${standardForm.originalNumVars}');
    }

    // 更新目标函数行
    for (var j = 0; j < numCols; j++) {
      if (j < standardForm.objective.length) {
        tableau.tableau[numRows][j] = -standardForm.objective[j];
      } else {
        tableau.tableau[numRows][j] = 0.0;
      }
    }

    if (debug) {
      print('目标函数行（重新计算前）: ${tableau.tableau[numRows]}');
    }

    // 重新计算目标函数行（消除基变量的贡献）
    for (var i = 0; i < numRows && i < tableau.basis.length; i++) {
      final basisVar = tableau.basis[i];
      if (basisVar < standardForm.objective.length) {
        final coeff = standardForm.objective[basisVar];
        if (coeff.abs() > _epsilon) {
          if (debug) {
            print('  消除基变量$basisVar (行$i)的贡献，系数=$coeff');
            if (i < 3) {
              print('    约束行$i: ${tableau.tableau[i]}');
            }
          }
          for (var j = 0; j <= numCols; j++) {
            tableau.tableau[numRows][j] += coeff * tableau.tableau[i][j];
          }
        }
      }
    }

    if (debug) {
      print('目标函数行（重新计算后）: ${tableau.tableau[numRows]}');
    }

    var iteration = 0;
    final basisHistory = <String>[];
    final objectiveHistory = <double>[];
    const maxHistorySize = 10;
    var preferNonDegenerate = false;

    while (iteration < _maxIterations) {
      if (debug && iteration < 5) {
        print('\n--- 第二阶段迭代 $iteration ---');
        print('基变量: ${tableau.basis}');
        print('目标函数行: ${tableau.tableau.last}');
        print('目标函数值: ${tableau.tableau.last.last}');
      }

      // 循环检测
      final basisKey = tableau.basis.toString();
      final currentObjective = tableau.tableau.last.last;

      if (basisHistory.contains(basisKey)) {
        final cycleStart = basisHistory.indexOf(basisKey);
        final cycleLength = basisHistory.length - cycleStart;

        if (debug) {
          print(
            '检测到循环：基变量状态在迭代$cycleStart和迭代${iteration}重复（循环长度=$cycleLength）',
          );
        }

        bool objectiveImproved = false;
        for (var i = cycleStart; i < objectiveHistory.length - 1; i++) {
          if ((isMaximize &&
                  objectiveHistory[i + 1] > objectiveHistory[i] + _epsilon) ||
              (!isMaximize &&
                  objectiveHistory[i + 1] < objectiveHistory[i] - _epsilon)) {
            objectiveImproved = true;
            break;
          }
        }

        if (!objectiveImproved) {
          if (debug) {
            print('目标函数值在循环中没有改进，尝试优先选择非退化行');
          }
          preferNonDegenerate = true;
          basisHistory.clear();
          objectiveHistory.clear();
        }
      }

      basisHistory.add(basisKey);
      objectiveHistory.add(currentObjective);
      if (basisHistory.length > maxHistorySize) {
        basisHistory.removeAt(0);
        objectiveHistory.removeAt(0);
      }

      // 检查是否最优
      if (_isOptimal(tableau, isMaximize)) {
        final rawValue = tableau.tableau[numRows][numCols];
        final solution = _extractSolution(tableau, standardForm, debug: debug);

        double finalValue;
        if (rawValue.abs() < _epsilon && solution != null) {
          // 直接从解计算最优值
          finalValue = 0.0;
          for (
            var i = 0;
            i < originalProblem.numVariables && i < solution.length;
            i++
          ) {
            finalValue +=
                originalProblem.objectiveCoefficients[i] * solution[i];
          }
        } else {
          finalValue = isMaximize ? -rawValue : rawValue;
        }

        if (debug) {
          print(
            '达到最优：rawValue=$rawValue, finalValue=$finalValue, solution=$solution',
          );
        }

        return LinearProgramResult.optimal(
          optimalValue: finalValue,
          solution: solution ?? [],
        );
      }

      // 选择入基变量
      final pivotCol = _findPivotColumn(tableau);
      if (pivotCol == -1) {
        return LinearProgramResult.unbounded();
      }

      if (debug && iteration < 5) {
        print('入基变量: $pivotCol');
      }

      // 选择出基变量
      final pivotRow = _findPivotRow(
        tableau,
        pivotCol,
        preferNonDegenerate: preferNonDegenerate,
      );
      if (pivotRow == -1) {
        if (debug) {
          print('警告：找不到出基变量，返回无界');
        }
        return LinearProgramResult.unbounded();
      }

      if (debug && iteration < 5) {
        print('出基变量: ${tableau.basis[pivotRow]} (行 $pivotRow)');
      }

      // 执行主元操作
      _pivot(tableau, pivotRow, pivotCol);

      iteration++;
    }

    return LinearProgramResult.unsolved(message: '达到最大迭代次数');
  }

  /// 检查是否达到最优
  static bool _isOptimal(_Tableau tableau, [bool isMaximize = false]) {
    final lastRow = tableau.tableau.last;
    for (var j = 0; j < lastRow.length - 1; j++) {
      // 跳过基变量
      if (tableau.basis.contains(j)) continue;

      // 对于标准化问题，如果有负的 reduced cost，可以改进
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
      // 跳过基变量
      if (tableau.basis.contains(j)) continue;

      if (lastRow[j] < minVal - _epsilon) {
        minVal = lastRow[j];
        pivotCol = j;
      }
    }

    return pivotCol;
  }

  /// 找到主元行（出基变量）
  /// [preferNonDegenerate] 如果为true，优先选择非退化行（RHS != 0）
  static int _findPivotRow(
    _Tableau tableau,
    int pivotCol, {
    bool preferNonDegenerate = false,
  }) {
    var minRatio = double.infinity;
    var pivotRow = -1;
    var bestNonDegenerateRow = -1;
    var minNonDegenerateRatio = double.infinity;

    for (var i = 0; i < tableau.tableau.length - 1; i++) {
      final pivotElement = tableau.tableau[i][pivotCol];
      if (pivotElement.abs() > _epsilon) {
        final rhs = tableau.tableau[i][tableau.tableau[0].length - 1];
        final isDegenerate = rhs.abs() < _epsilon;

        // 对于正的系数，需要RHS >= 0
        if (pivotElement > _epsilon && rhs >= -_epsilon) {
          final ratio = rhs / pivotElement;
          if (ratio >= 0) {
            // 记录非退化行
            if (preferNonDegenerate && !isDegenerate) {
              if (ratio < minNonDegenerateRatio - _epsilon) {
                minNonDegenerateRatio = ratio;
                bestNonDegenerateRow = i;
              } else if ((ratio - minNonDegenerateRatio).abs() < _epsilon &&
                  i < bestNonDegenerateRow) {
                bestNonDegenerateRow = i;
              }
            }
            // 更新全局最小比值
            if (ratio < minRatio - _epsilon) {
              minRatio = ratio;
              pivotRow = i;
            } else if ((ratio - minRatio).abs() < _epsilon &&
                (pivotRow == -1 || i < pivotRow)) {
              pivotRow = i;
            }
          }
        } else if (pivotElement < -_epsilon && rhs <= _epsilon) {
          // 对于负的系数，需要RHS <= 0
          final ratio = rhs / pivotElement;
          if (ratio >= 0) {
            if (preferNonDegenerate && !isDegenerate) {
              if (ratio < minNonDegenerateRatio - _epsilon) {
                minNonDegenerateRatio = ratio;
                bestNonDegenerateRow = i;
              } else if ((ratio - minNonDegenerateRatio).abs() < _epsilon &&
                  i < bestNonDegenerateRow) {
                bestNonDegenerateRow = i;
              }
            }
            if (ratio < minRatio - _epsilon) {
              minRatio = ratio;
              pivotRow = i;
            } else if ((ratio - minRatio).abs() < _epsilon &&
                (pivotRow == -1 || i < pivotRow)) {
              pivotRow = i;
            }
          }
        }
      }
    }

    // 如果优先选择非退化行且找到了非退化行，检查其比值是否等于全局最小比值
    if (preferNonDegenerate && bestNonDegenerateRow != -1) {
      if ((minNonDegenerateRatio - minRatio).abs() < _epsilon) {
        return bestNonDegenerateRow;
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
  static List<double>? _extractSolution(
    _Tableau tableau,
    _StandardForm standardForm, {
    bool debug = false,
  }) {
    final solution = List<double>.filled(standardForm.originalNumVars, 0.0);

    if (debug) {
      print('提取解向量：基变量=${tableau.basis}');
      print('originalNumVars: ${standardForm.originalNumVars}');
    }

    for (var i = 0; i < tableau.basis.length; i++) {
      final varIdx = tableau.basis[i];
      final rhsIdx = tableau.tableau[0].length - 1;
      final rhs = tableau.tableau[i][rhsIdx];

      if (debug) {
        print('  行$i: 基变量=$varIdx, RHS=$rhs');
      }

      if (varIdx < standardForm.originalNumVars) {
        solution[varIdx] = rhs;
        if (debug) {
          print('    变量$varIdx (原始变量) = $rhs');
        }
      } else if (debug) {
        print('    变量$varIdx (非原始变量，跳过)');
      }
    }

    if (debug) {
      print('提取的解向量: $solution');
    }

    return solution;
  }

  /// 移除人工变量
  static _Tableau _removeArtificialVars(
    _Tableau tableau,
    _StandardForm standardForm,
  ) {
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
