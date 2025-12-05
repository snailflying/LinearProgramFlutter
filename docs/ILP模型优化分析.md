# ILP模型优化分析

## 当前模型复杂度

### 变量数量
- `y_{o,i}`: O × P 个（订单数 × 活动数）
- `A_i`, `C_i`, `D_i`: 各 P 个
- `z_i` 或 `t_i`: P 个

**总变量数**: O × P + 4P = O(O × P)

### 约束数量
- 每单一个活动约束: O 个
- `y_{o,i} <= 1` 约束: O × P 个  ⚠️ **冗余！**
- `A_i`, `C_i` 定义约束: 2P 个
- 活动约束（门槛、优惠）: 约 4P 个

**总约束数**: O + O×P + 6P = O(O × P)

### 整数变量数量
- `y_{o,i}`: O × P 个
- `z_i` 或 `t_i`: P 个

**总整数变量**: O × P + P = O(O × P)

---

## 🔴 主要性能瓶颈

### 1. 冗余约束 `y_{o,i} <= 1`
当前代码中每个 `y_{o,i}` 都添加了单独的上界约束：
```javascript
const upperRow = `y_${order.id}_${promo.id}_le1`;
this.constraints[upperRow] = lessEq(1);
```

**问题**: 二进制变量 y ∈ {0,1} 的上界约束是冗余的！YALPS 的 integers 声明已经隐含了非负约束，再加上 `sum_i y_{o,i} <= 1`，天然保证每个 y <= 1。

**优化**: 删除这 O×P 个约束，约束数量减少近一半。

### 2. 聚合变量 A_i, C_i 的冗余
当前为每个活动定义了连续变量 A_i 和 C_i：
```
A_i = sum_o a_{o,i} * y_{o,i}
C_i = sum_o c_{o,i} * y_{o,i}
```

**问题**: 这些辅助变量可以被直接替换消除。

**优化**: 在约束中直接使用 `sum_o a_{o,i} * y_{o,i}` 代替 A_i，减少 2P 个变量和 2P 个约束。

### 3. 打折类活动的非线性近似
当前打折类使用 Big-M 方法引入二进制变量 z_i：
```
D_i <= alpha * A_i          (上界)
D_i <= alpha * M_a * z_i    (gating)
```

**问题**: Big-M 约束会削弱 LP 松弛的紧度，导致分支定界效率低。

### 4. 稀疏性未利用
很多订单与活动之间没有交集（a_{o,i} = 0），但当前模型仍创建了对应的 y_{o,i} 变量。

**优化**: 预计算可行的 (订单, 活动) 组合，只为有效组合创建变量。

---

## ✅ 已实施的优化方案

### 方案1: 删除冗余约束 ✅ 已实施
- 删除 `y_{o,i} <= 1` 约束
- 收益: 约束数量减少约 50%

### 方案2: 稀疏变量优化 ✅ 已实施
- 只为 `a_{o,i} > 0` 的组合创建 `y_{o,i}` 变量
- 收益: 变量和约束数量大幅减少（取决于稀疏程度）

### 方案3: 二进制变量声明优化 ✅ 已实施
- 使用 YALPS 的 `binaries` 声明代替 `integers`
- 二进制变量求解效率更高

---

## ✅ 活动分组优化方案（重点优化）

### 核心思想

ILP（整数线性规划）问题的求解复杂度随变量和约束数量**指数级增长**。分组优化的核心思想是：

> **将一个大规模 ILP 问题分解为多个小规模独立子问题，分别求解后合并结果。**

### 问题分析

在营销活动最优组合问题中：
- 每个订单最多参加一个活动
- 不同活动有不同的作用范围（`scopeTicketTypeIds`）

**关键洞察**：如果两个活动 A 和 B 的**潜在参与订单完全不相交**，那么：
- 订单选择参加活动 A 不会影响活动 B 的优化结果
- 它们的决策是**完全独立的**

### 分组算法

```
活动1: 作用范围 [票种A, 票种B]  →  覆盖订单 {O1, O2}
活动2: 作用范围 [票种C, 票种D]  →  覆盖订单 {O3, O4}
活动3: 作用范围 [票种A, 票种C]  →  覆盖订单 {O1, O3}
```

使用**并查集**算法判断活动间的关联：

1. 活动1 和 活动2：覆盖订单无交集 → 可独立
2. 活动1 和 活动3：都覆盖 O1 → **必须同组**（O1 只能选一个活动）
3. 活动2 和 活动3：都覆盖 O3 → **必须同组**

最终：活动1、2、3 都在同一组（通过传递性关联）

### 复杂度优化分析

假设原问题有 N 个订单、M 个活动：
- **不分组**：变量数 ≈ N×M，约束数 ≈ N + M×5

如果能分成 K 个均等组（每组 N/K 订单、M/K 活动）：
- **分组后**：每组变量 ≈ (N/K)×(M/K) = NM/K²

由于 ILP 是 NP-hard，复杂度近似指数级：
- 原问题：≈ O(2^(NM))
- 分组后：≈ K × O(2^(NM/K²))

**当 K=10 时，理论加速可达 10⁺ 倍以上！**

### 实现方案

#### 1. 新增 `PromotionGrouper` 类

```javascript
// src/ilp/PromotionGrouper.js
export default class PromotionGrouper {
    /**
     * 将活动按作用域分组
     * @param {Object[]} promotions - 活动数组
     * @param {Object[]} orders - 订单数组
     * @returns {Object[]} 分组结果 [{ groupId, promotions, orders }]
     */
    static groupPromotions(promotions, orders) {
        // 使用并查集合并有共同订单的活动
        // ...
    }
}
```

#### 2. 修改 `ILPSolver.solve` 方法

```javascript
static solve(rules, tickets, options = {}) {
    // 1. 分组
    const groups = PromotionGrouper.groupPromotions(promotions, orders);
    
    // 2. 分别求解各组
    const groupResults = groups.map(group => {
        const builder = new ILPModelBuilder(group.promotions, group.orders);
        const model = builder.build();
        return yalpsSolve(model);
    });
    
    // 3. 合并结果
    return this._mergeGroupResults(groupResults, ...);
}
```

#### 3. 新增 `enableGrouping` 选项

```javascript
// 使用方式
Strategy.bestChoice(rules, tickets, { enableGrouping: true });  // 默认启用
Strategy.bestChoice(rules, tickets, { enableGrouping: false }); // 禁用分组
```

### 性能提升效果

| 场景 | 禁用分组 | 启用分组 | 分组数 | 提升比例 |
|-----|---------|---------|-------|---------|
| 重叠范围(30订单×10规则) | 1026ms | 1010ms | 1 | 1.02x |
| **独立范围(30订单×10规则)** | 1.01ms | 0.16ms | 10 | **6.44x** |
| **独立范围(50订单×20规则)** | 9.49ms | 0.33ms | 20 | **29.03x** |
| **独立范围(80订单×30规则)** | 37.54ms | 0.52ms | 30 | **71.95x** |

### 适用场景

分组优化在以下场景效果最佳：
- ✅ 多个活动作用于**不同票种/项目/场次**
- ✅ 订单票种相对集中（不跨多个活动范围）
- ⚠️ 所有活动范围重叠时，无法分组，退化为原始求解

---

## 📋 后续可优化方向

### 方案A: 消除聚合变量（中等难度）
- 用 `sum_o a_{o,i} * y_{o,i}` 直接替代 A_i
- 预期收益: 变量减少 2P，约束减少 2P

### 方案B: 求解器参数调优
- 设置求解超时
- 使用启发式初始解
- 调整分支策略

### 方案C: 拉格朗日松弛（高难度）
- 松弛耦合约束
- 使用次梯度法求解

### 方案D: 列生成（高难度）
- 适用于大规模稀疏问题
- 动态生成变量

---

## 当前限制

规则数量 >15 且规则范围高度重叠时，求解时间仍可能较长。这是 ILP 问题的固有复杂度，进一步优化需要考虑：
- 更激进的问题分解策略
- 启发式初始解 + 精确求解的混合方法
- 放松最优性要求（使用 tolerance 参数接受次优解）

