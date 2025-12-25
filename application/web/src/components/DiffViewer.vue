<template>
  <div class="diff-viewer">
    <div v-if="!hasDiff" class="no-diff">
      <a-empty description="首次创建，无差异对比" :image="Empty.PRESENTED_IMAGE_SIMPLE" />
    </div>
    <div v-else class="diff-content">
      <div v-for="(change, key) in diff" :key="key" class="diff-line-group">
        <!-- 字段删除 -->
        <div v-if="change.old !== null && change.new === null" class="diff-line diff-remove">
          <span class="diff-symbol">-</span>
          <span class="diff-key">"{{ key }}"</span>
          <span class="diff-colon">:</span>
          <span class="diff-value">{{ formatValue(change.old) }}</span>
        </div>
        
        <!-- 字段新增 -->
        <div v-else-if="change.old === null && change.new !== null" class="diff-line diff-add">
          <span class="diff-symbol">+</span>
          <span class="diff-key">"{{ key }}"</span>
          <span class="diff-colon">:</span>
          <span class="diff-value">{{ formatValue(change.new) }}</span>
        </div>
        
        <!-- 字段修改 -->
        <div v-else-if="!deepEqual(change.old, change.new)" class="diff-line-pair">
          <div class="diff-line diff-remove">
            <span class="diff-symbol">-</span>
            <span class="diff-key">"{{ key }}"</span>
            <span class="diff-colon">:</span>
            <span class="diff-value">{{ formatValue(change.old) }}</span>
          </div>
          <div class="diff-line diff-add">
            <span class="diff-symbol">+</span>
            <span class="diff-key">"{{ key }}"</span>
            <span class="diff-colon">:</span>
            <span class="diff-value">{{ formatValue(change.new) }}</span>
          </div>
        </div>
        
        <!-- 字段未变化（可选显示） -->
        <div v-else-if="showUnchanged" class="diff-line diff-unchanged">
          <span class="diff-symbol"> </span>
          <span class="diff-key">"{{ key }}"</span>
          <span class="diff-colon">:</span>
          <span class="diff-value">{{ formatValue(change.new) }}</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';
import { Empty } from 'ant-design-vue';

interface DiffDetail {
  old: any;
  new: any;
}

interface Props {
  diff: Record<string, DiffDetail>;
  showUnchanged?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  showUnchanged: false
});

// 检查是否有实质性变化
const hasDiff = computed(() => {
  return Object.values(props.diff).some(change => 
    !deepEqual(change.old, change.new)
  );
});

// 格式化值用于显示
const formatValue = (value: any): string => {
  if (value === null || value === undefined) {
    return 'null';
  }
  if (typeof value === 'string') {
    return `"${value}"`;
  }
  if (typeof value === 'object') {
    return JSON.stringify(value);
  }
  return String(value);
};

// 深度比较
const deepEqual = (a: any, b: any): boolean => {
  if (a === b) return true;
  if (a === null || b === null) return false;
  if (typeof a !== typeof b) return false;
  if (typeof a !== 'object') return a === b;
  
  const keysA = Object.keys(a);
  const keysB = Object.keys(b);
  if (keysA.length !== keysB.length) return false;
  
  return keysA.every(key => deepEqual(a[key], b[key]));
};
</script>

<style scoped>
.diff-viewer {
  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
  font-size: 13px;
  line-height: 1.6;
  background: #f5f5f5;
  border-radius: 4px;
  padding: 12px;
}

.no-diff {
  padding: 20px;
  text-align: center;
}

.diff-content {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.diff-line-group {
  margin-bottom: 4px;
}

.diff-line {
  padding: 2px 8px;
  border-radius: 2px;
  display: flex;
  align-items: baseline;
  gap: 4px;
}

.diff-line-pair {
  display: flex;
  flex-direction: column;
  gap: 2px;
}

.diff-symbol {
  width: 16px;
  font-weight: bold;
  flex-shrink: 0;
}

.diff-key {
  color: #0451a5;
  font-weight: 500;
}

.diff-colon {
  color: #666;
}

.diff-value {
  color: #098658;
  word-break: break-all;
}

/* 新增样式 */
.diff-add {
  background-color: #e6ffed;
  border-left: 3px solid #28a745;
}

.diff-add .diff-symbol {
  color: #22863a;
}

/* 删除样式 */
.diff-remove {
  background-color: #ffebe9;
  border-left: 3px solid #d73a49;
}

.diff-remove .diff-symbol {
  color: #b60000;
}

.diff-remove .diff-value {
  color: #b60000;
}

/* 未变化样式 */
.diff-unchanged {
  background-color: #fafafa;
  border-left: 3px solid #e1e4e8;
}

.diff-unchanged .diff-symbol {
  color: #6a737d;
}

.diff-unchanged .diff-key,
.diff-unchanged .diff-value {
  color: #6a737d;
}
</style>
