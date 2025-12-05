#!/usr/bin/env python3
"""
使用 scipy.optimize.linprog 验证测试用例是否有可行解
"""
from scipy.optimize import linprog

# 测试用例1：简单满额立减测试
# 最大化 D
# 约束：
#   A = 420 * y => A - 420*y = 0
#   A >= 400 * t => A - 400*t >= 0
#   D = 90 * t => D - 90*t = 0
#   y <= 1
#   t <= y => y - t >= 0
# 变量：y, A, D, t

print("=== 测试用例1：简单满额立减测试 ===")

# 目标函数：最大化 D，即最小化 -D
c = [0, 0, -1, 0]  # -D (因为linprog是最小化)

# 约束矩阵
A_ub = [
    # A - 400*t >= 0 => -A + 400*t <= 0
    [0, -1, 0, 400],
    # y - t >= 0 => -y + t <= 0
    [-1, 0, 0, 1],
    # y <= 1 => y <= 1
    [1, 0, 0, 0],
]
b_ub = [0, 0, 1]

# 等式约束
A_eq = [
    # A - 420*y = 0
    [0, 1, 0, -420],
    # D - 90*t = 0
    [0, 0, 1, -90],
]
b_eq = [0, 0]

# 变量边界
bounds = [
    (0, 1),      # y: [0, 1]
    (0, None),   # A: [0, inf)
    (0, None),   # D: [0, inf)
    (0, 1),      # t: [0, 1]
]

try:
    result = linprog(c, A_ub=A_ub, b_ub=b_ub, A_eq=A_eq, b_eq=b_eq, bounds=bounds, method='highs')
    print(f"状态: {result.status}")
    print(f"消息: {result.message}")
    if result.success:
        print(f"最优值: {-result.fun}")  # 取负，因为linprog是最小化
        print(f"最优解: {result.x}")
        print(f"y={result.x[0]}, A={result.x[1]}, D={result.x[2]}, t={result.x[3]}")
    else:
        print("无可行解或问题无界")
except Exception as e:
    print(f"错误: {e}")

print("\n" + "="*50 + "\n")

# 测试用例2：检查是否有其他问题
print("=== 测试用例2：简化版本 ===")
# 最小化问题：min z = x + 2y
# 约束: x + y >= 3
# x >= 0, y >= 0

c2 = [1, 2]
A_ub2 = [[-1, -1]]  # -x - y <= -3 => x + y >= 3
b_ub2 = [-3]
bounds2 = [(0, None), (0, None)]

try:
    result2 = linprog(c2, A_ub=A_ub2, b_ub=b_ub2, bounds=bounds2, method='highs')
    print(f"状态: {result2.status}")
    print(f"消息: {result2.message}")
    if result2.success:
        print(f"最优值: {result2.fun}")
        print(f"最优解: {result2.x}")
    else:
        print("无可行解或问题无界")
except Exception as e:
    print(f"错误: {e}")

