#!/bin/bash
cd /home/engine/project

echo "=== Git Status ==="
git status

echo ""
echo "=== Staging Changes ==="
git add -A

echo ""
echo "=== Committing ==="
git commit -m "fix(web): 修复 Ant Design Vue Modal 弹窗不显示问题

- 将 v-model:open 替换为 :visible 以适配 Ant Design Vue 3.x
- 修复 OEM.vue 创建订单弹窗
- 修复 Manufacturer.vue 状态更新弹窗
- 修复 Carrier.vue 取货和位置更新弹窗
- 修复 Platform.vue 详情弹窗

issue: #modal-compat"

echo ""
echo "=== Push to Remote ==="
git push origin merge-openapi-feasibility-spike-into-main
