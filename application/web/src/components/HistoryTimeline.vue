<template>
  <div class="history-timeline">
    <a-spin :spinning="loading">
      <a-empty v-if="!loading && history.length === 0" description="暂无历史记录" />
      
      <a-timeline v-else mode="left" class="timeline-container">
        <a-timeline-item
          v-for="(record, index) in history"
          :key="record.txId"
          :color="getTimelineColor(record)"
        >
          <!-- 时间轴节点标题 -->
          <template #label>
            <div class="timeline-label">
              <div class="timeline-timestamp">{{ formatTimestamp(record.timestamp) }}</div>
              <div class="timeline-status">
                <a-tag :color="getStatusColor(record)">
                  {{ getStatusText(record) }}
                </a-tag>
              </div>
            </div>
          </template>
          
          <!-- 时间轴节点内容 -->
          <div class="timeline-content">
            <!-- 元数据面板 -->
            <div class="metadata-panel">
              <div class="metadata-row">
                <span class="metadata-label">交易ID:</span>
                <a-tooltip :title="record.txId">
                  <span class="metadata-value txid">{{ truncateTxId(record.txId) }}</span>
                </a-tooltip>
              </div>
              <div class="metadata-row">
                <span class="metadata-label">操作类型:</span>
                <a-tag :color="record.isDelete ? 'red' : 'green'" size="small">
                  {{ record.isDelete ? '删除' : '更新/创建' }}
                </a-tag>
              </div>
              <div class="metadata-row" v-if="index === history.length - 1">
                <a-tag color="blue">首次创建</a-tag>
              </div>
            </div>

            <!-- 操作按钮 -->
            <div class="action-buttons">
              <a-button
                size="small"
                @click="toggleExpand(record.txId, 'json')"
                :type="expandedItems[record.txId]?.json ? 'primary' : 'default'"
              >
                <template #icon>
                  <span v-if="expandedItems[record.txId]?.json">▲</span>
                  <span v-else>▼</span>
                </template>
                {{ expandedItems[record.txId]?.json ? '收起' : '展开' }} JSON
              </a-button>
              
              <a-button
                size="small"
                @click="toggleExpand(record.txId, 'diff')"
                :type="expandedItems[record.txId]?.diff ? 'primary' : 'default'"
                :disabled="index === history.length - 1"
              >
                <template #icon>
                  <span v-if="expandedItems[record.txId]?.diff">▲</span>
                  <span v-else>▼</span>
                </template>
                {{ expandedItems[record.txId]?.diff ? '收起' : '展开' }} Diff
              </a-button>
            </div>

            <!-- JSON 展开区域 -->
            <div v-show="expandedItems[record.txId]?.json" class="expand-section">
              <div class="section-title">
                <span class="title-icon">📄</span>
                <span>完整状态数据 (JSON)</span>
              </div>
              <JsonViewer :data="record.value" />
            </div>

            <!-- Diff 展开区域 -->
            <div v-show="expandedItems[record.txId]?.diff && index < history.length - 1" class="expand-section">
              <div class="section-title">
                <span class="title-icon">🔄</span>
                <span>与上一版本对比 (Diff)</span>
              </div>
              <DiffViewer :diff="record.diff" />
            </div>
          </div>
        </a-timeline-item>
      </a-timeline>
    </a-spin>
  </div>
</template>

<script setup lang="ts">
import { ref, reactive } from 'vue';
import DiffViewer from './DiffViewer.vue';
import JsonViewer from './JsonViewer.vue';

interface DiffDetail {
  old: any;
  new: any;
}

interface HistoryRecord {
  txId: string;
  timestamp: string | Date;
  isDelete: boolean;
  value: any;
  diff: Record<string, DiffDetail>;
}

interface Props {
  history: HistoryRecord[];
  loading?: boolean;
}

const props = withDefaults(defineProps<Props>(), {
  loading: false
});

// 展开状态管理
const expandedItems = reactive<Record<string, { json?: boolean; diff?: boolean }>>({});

// 切换展开/折叠
const toggleExpand = (txId: string, type: 'json' | 'diff') => {
  if (!expandedItems[txId]) {
    expandedItems[txId] = {};
  }
  expandedItems[txId][type] = !expandedItems[txId][type];
};

// 格式化时间戳
const formatTimestamp = (timestamp: string | Date): string => {
  const date = new Date(timestamp);
  return date.toLocaleString('zh-CN', {
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
    hour12: false
  });
};

// 截断交易ID
const truncateTxId = (txId: string): string => {
  if (txId.length <= 16) return txId;
  return `${txId.substring(0, 8)}...${txId.substring(txId.length - 8)}`;
};

// 获取时间轴颜色
const getTimelineColor = (record: HistoryRecord): string => {
  if (record.isDelete) return 'red';
  return 'blue';
};

// 获取状态文本
const getStatusText = (record: HistoryRecord): string => {
  if (record.isDelete) return '已删除';
  if (!record.value) return '--';
  
  const status = record.value.status;
  const statusMap: Record<string, string> = {
    CREATED: '已创建',
    ACCEPTED: '已接受',
    PRODUCING: '生产中',
    PRODUCED: '已生产',
    READY: '待取货',
    SHIPPED: '运输中',
    DELIVERED: '已送达',
    RECEIVED: '已签收'
  };
  
  return statusMap[status] || status || '--';
};

// 获取状态颜色
const getStatusColor = (record: HistoryRecord): string => {
  if (record.isDelete) return 'red';
  if (!record.value) return 'default';
  
  const status = record.value.status;
  const colorMap: Record<string, string> = {
    CREATED: 'blue',
    ACCEPTED: 'cyan',
    PRODUCING: 'orange',
    PRODUCED: 'purple',
    READY: 'geekblue',
    SHIPPED: 'gold',
    DELIVERED: 'lime',
    RECEIVED: 'green'
  };
  
  return colorMap[status] || 'default';
};
</script>

<style scoped>
.history-timeline {
  padding: 16px 0;
}

.timeline-container {
  margin-top: 20px;
}

/* 时间轴标签区域 */
.timeline-label {
  text-align: right;
  padding-right: 16px;
}

.timeline-timestamp {
  font-size: 13px;
  color: #666;
  margin-bottom: 4px;
  font-family: 'Monaco', 'Menlo', monospace;
}

.timeline-status {
  margin-top: 4px;
}

/* 时间轴内容区域 */
.timeline-content {
  background: #fff;
  border: 1px solid #e8e8e8;
  border-radius: 4px;
  padding: 16px;
  min-width: 500px;
}

/* 元数据面板 */
.metadata-panel {
  margin-bottom: 12px;
  padding-bottom: 12px;
  border-bottom: 1px solid #f0f0f0;
}

.metadata-row {
  display: flex;
  align-items: center;
  margin-bottom: 8px;
  gap: 8px;
}

.metadata-row:last-child {
  margin-bottom: 0;
}

.metadata-label {
  font-weight: 500;
  color: #666;
  min-width: 70px;
}

.metadata-value {
  color: #262626;
}

.metadata-value.txid {
  font-family: 'Monaco', 'Menlo', monospace;
  font-size: 12px;
  color: #1890ff;
  cursor: help;
}

/* 操作按钮 */
.action-buttons {
  display: flex;
  gap: 8px;
  margin-bottom: 12px;
}

/* 展开区域 */
.expand-section {
  margin-top: 16px;
  animation: slideDown 0.3s ease-out;
}

@keyframes slideDown {
  from {
    opacity: 0;
    transform: translateY(-10px);
  }
  to {
    opacity: 1;
    transform: translateY(0);
  }
}

.section-title {
  display: flex;
  align-items: center;
  gap: 8px;
  margin-bottom: 8px;
  font-weight: 500;
  color: #262626;
  font-size: 14px;
}

.title-icon {
  font-size: 16px;
}

/* 响应式 */
@media (max-width: 768px) {
  .timeline-content {
    min-width: auto;
  }
  
  .action-buttons {
    flex-direction: column;
  }
  
  .action-buttons .ant-btn {
    width: 100%;
  }
}
</style>
