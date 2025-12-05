# 基于 ILP 的智能推荐系统设计方案

## 1. 背景与目标

当前的促销引擎基于 ILP (整数线性规划) 实现了全局最优的优惠计算。然而，现有的 `SuggestionCalculator` 仅基于剩余票据进行简单的凑单建议，存在以下局限性：
1.  **局部视角**: 无法感知全局最优解的变化。可能出现"补了A导致原本更优的B规则失效"的情况。
2.  **被动计算**: 只能基于当前状态计算 Gap，缺乏主动规划能力。

本方案旨在设计一套**"求解即推荐"**的智能系统，利用 ILP 的数学特性，在计算最优解的同时直接产出**全局最优的凑单建议**。

## 2. 核心理念：虚拟补单变量 (Virtual Slack Variables)

传统的推荐系统通常采用 "试算-评估" 模式（Try-and-Error），即假设购买了商品X，重新跑一遍计算看是否划算。这种方式性能开销大且难以覆盖所有组合。

本方案采用 **"模型内嵌推荐"** 的思路：
在 ILP 模型中引入**虚拟补单变量 ($v_i$)**，允许求解器在计算过程中"借用"虚拟商品来满足规则门槛，但同时对这种"借用"施加惩罚成本。

### 数学模型变化

**原约束**:
$$ \sum tickets \ge Threshold \cdot z_i $$
*(只有真实票据足够，才能激活规则 $z_i$)*

**新约束 (带虚拟补单)**:
$$ \sum tickets + \mathbf{v_i} \ge Threshold \cdot z_i $$
*(真实票据 + **虚拟补单量** $\ge$ 门槛)*

**目标函数 (Objective Function)**:
$$ Maximize: \sum (Discount_i \cdot z_i) - \sum (Cost_i \cdot v_i) $$

*   $Discount_i$: 规则带来的优惠金额（正收益）。
*   $v_i$: 规则 $i$ 需要的虚拟补单量。
*   $Cost_i$: 补单的惩罚成本（通常关联商品的预估价格）。

### 决策逻辑
求解器会自动权衡：
*   如果 $Discount_i > Cost_i \cdot v_i$：说明获得的优惠足以覆盖补单成本，求解器会选择激活规则，并输出 $v_i > 0$。这即是一条**高价值推荐**。
*   如果 $Discount_i < Cost_i \cdot v_i$：说明补单不划算，求解器会令 $z_i=0, v_i=0$。

## 3. 系统架构设计

### 3.1 模块调整

建议在 `src/ilp` 下进行如下扩展：

```text
src/ilp/
├── builder/
│   ├── ILPModelBuilder.js       // [修改] 增加 buildRecommendationModel 方法
│   └── strategies/              // [修改] 各策略增加对虚拟变量的支持
├── parser/
│   └── ILPResultParser.js       // [修改] 解析 v_i 变量，生成 Recommendation 对象
└── recommendation/              // [新增]
    ├── RecommendationEngine.js  // 推荐引擎入口
    └── CostEstimator.js         // 成本估算器（计算 v_i 的 Cost）
```

### 3.2 关键流程

1.  **成本估算**: `CostEstimator` 根据当前购物车或历史数据，估算每种规则所需的"补单单价"。
2.  **模型构建**: `ILPModelBuilder` 在构建约束时，为每个规则注入虚拟变量 $v_i$，并在目标函数中添加惩罚项。
3.  **全局求解**: 调用 `yalps` 进行求解。
4.  **结果解析**: `ILPResultParser` 检查所有 $v_i > 0$ 且 $z_i=1$ 的规则，将其转换为具体的商品推荐建议。

## 4. 详细设计

### 4.1 虚拟变量命名规范
*   `v_{ruleId}_{ticketType}`: 表示为规则 `ruleId` 补充 `ticketType` 类型的虚拟票数量。

### 4.2 惩罚系数 (Penalty) 调优
惩罚系数直接决定了推荐的"激进程度"。

*   **保守策略**: $Cost = Price \times 1.0$。只有当优惠金额完全覆盖商品原价时才推荐（即"白送"或"倒贴"）。
*   **激进策略**: $Cost = Price \times 0.1$。只要有一点优惠就推荐升级（适合"满额打折"等高门槛活动）。
*   **智能策略**: $Cost = Price \times (1 - \text{用户价格敏感度})$。

### 4.3 推荐结果对象

```javascript
class Recommendation {
    constructor(rule, virtualTickets, expectedDiscount) {
        this.rule = rule;
        this.itemsToAdd = virtualTickets; // 需要补购的商品列表
        this.netBenefit = expectedDiscount - virtualTickets.totalPrice; // 净收益
        this.roi = expectedDiscount / virtualTickets.totalPrice; // 投资回报率
    }
}
```

## 5. 优势与风险

### 优势
1.  **全局最优**: 推荐结果是经过全局规划的，不会出现"拆东墙补西墙"的情况。
2.  **性能卓越**: 一次求解即可获得所有推荐，无需多次循环试算。
3.  **逻辑统一**: 推荐逻辑与计算逻辑同源，保证了"所见即所得"。

### 风险与对策
1.  **模型复杂度增加**: 引入大量虚拟变量可能导致求解变慢。
    *   *对策*: 仅对 Gap 较小（如进度 > 50%）的规则引入虚拟变量，进行剪枝。
2.  **非线性问题**: 某些规则（如打折）的收益取决于总金额（含虚拟商品），这可能引入非线性。
    *   *对策*: 使用预估均价将非线性问题线性化，或采用分段线性逼近。

## 6. 实施路线图

1.  **原型验证 (Phase 1)**:
    *   选取最简单的 `OVER_QTY_DISCOUNT` (满件打折) 规则。
    *   硬编码虚拟变量和惩罚系数，验证求解器是否能输出预期的 $v_i$。
2.  **框架改造 (Phase 2)**:
    *   重构 `ILPModelBuilder`，支持可配置的 `enableRecommendation` 模式。
    *   实现 `CostEstimator`。
3.  **全面推广 (Phase 3)**:
    *   将逻辑推广到所有 Strategy。
    *   完善结果解析和前端展示数据结构。
