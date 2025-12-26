<template>
  <div class="history-timeline">
    <a-spin :spinning="loading">
      <a-empty v-if="!loading && history.length === 0" description="暂无历史记录" />
      
      <a-row v-else :gutter="24" class="timeline-layout">
        <!-- 左侧时间轴 (1/3) -->
        <a-col :span="8" class="timeline-side">
          <div class="timeline-list-container">
            <a-timeline mode="left">
              <a-timeline-item
                v-for="(record, index) in history"
                :key="record.txId"
                :color="getTimelineColor(record)"
                class="clickable-timeline-item"
                :class="{ active: selectedTxId === record.txId }"
                @click="selectedTxId = record.txId"
              >
                <div class="timeline-item-content">
                  <div class="timeline-item-time">{{ formatTimestamp(record.timestamp) }}</div>
                  <div class="timeline-item-status">
                    <a-tag :color="getStatusColor(record)" size="small">
                      {{ getStatusText(record) }}
                    </a-tag>
                  </div>
                </div>
              </a-timeline-item>
            </a-timeline>
          </div>
        </a-col>

        <!-- 右侧详情展示 (2/3) -->
        <a-col :span="16" class="detail-side">
          <div v-if="selectedRecord" class="detail-container">
            <!-- 头部元数据 -->
            <div class="detail-header">
              <div class="detail-title">版本详情</div>
              <div class="metadata-grid">
                <div class="metadata-item">
                  <span class="label">交易ID:</span>
                  <span class="value txid">{{ selectedRecord.txId }}</span>
                </div>
                <div class="metadata-item">
                  <span class="label">提交时间:</span>
                  <span class="value">{{ formatTimestamp(selectedRecord.timestamp) }}</span>
                </div>
                <div class="metadata-item">
                  <span class="label">操作类型:</span>
                  <a-tag :color="selectedRecord.isDelete ? 'red' : 'green'" size="small">
                    {{ selectedRecord.isDelete ? '删除' : '更新/创建' }}
                  </a-tag>
                  <a-tag v-if="selectedIndex === history.length - 1" color="blue" size="small" style="margin-left: 8px">首次创建</a-tag>
                </div>
              </div>
            </div>

            <!-- 内容切换区域 -->
            <div class="detail-content">
              <a-tabs v-model:activeKey="activeTab" size="small">
                <a-tab-pane key="diff" tab="数据对比 (Diff)">
                  <div class="pane-content">
                    <div v-if="selectedIndex === history.length - 1" class="first-version-hint">
                      <a-empty description="这是该记录的初始版本，无历史对比数据" />
                    </div>
                    <DiffViewer v-else :diff="selectedRecord.diff" />
                  </div>
                </a-tab-pane>
                <a-tab-pane key="json" tab="完整状态 (JSON)">
                  <div class="pane-content">
                    <JsonViewer :data="selectedRecord.value" />
                  </div>
                </a-tab-pane>
              </a-tabs>
            </div>
          </div>
          <div v-else class="empty-detail">
            <a-empty description="请选择左侧记录查看详情" />
          </div>
        </a-col>
      </a-row>
    </a-spin>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, watch } from 'vue';
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

// 状态管理
const selectedTxId = ref<string | null>(null);
const activeTab = ref('diff');

// 监听 history 变化，自动选择第一条
watch(() => props.history, (newHistory) => {
  if (newHistory && newHistory.length > 0) {
    if (!selectedTxId.value || !newHistory.find(r => r.txId === selectedTxId.value)) {
      selectedTxId.value = newHistory[0].txId;
    }
  }
}, { immediate: true });

const selectedRecord = computed(() => props.history.find(r => r.txId === selectedTxId.value));
const selectedIndex = computed(() => props.history.findIndex(r => r.txId === selectedTxId.value));

// 监听选中项变化，如果是首个版本且当前在 diff 标签页，则切换到 json 标签页
watch(selectedIndex, (newIndex) => {
  if (newIndex === props.history.length - 1 && activeTab.value === 'diff' && props.history.length > 0) {
    activeTab.value = 'json';
  } else if (newIndex !== props.history.length - 1 && newIndex !== -1) {
    activeTab.value = 'diff';
  }
});

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
  height: 100%;
}

.timeline-layout {
  min-height: 500px;
}

.timeline-side {
  border-right: 1px solid #f0f0f0;
  padding-right: 16px;
  max-height: 65vh;
  overflow-y: auto;
}

.clickable-timeline-item {
  cursor: pointer;
  padding: 8px;
  border-radius: 4px;
  transition: all 0.3s;
  margin-bottom: 0 !important;
  padding-bottom: 20px !important;
}

.clickable-timeline-item:hover {
  background: #f5f5f5;
}

.clickable-timeline-item.active {
  background: #e6f7ff;
}

.timeline-item-content {
  display: flex;
  flex-direction: column;
  gap: 4px;
}

.timeline-item-time {
  font-size: 13px;
  color: #666;
  font-family: 'Monaco', 'Menlo', monospace;
}

.detail-side {
  padding-left: 24px;
  max-height: 65vh;
  overflow-y: auto;
}

.detail-container {
  display: flex;
  flex-direction: column;
  gap: 20px;
}

.detail-header {
  background: #fafafa;
  padding: 16px;
  border-radius: 4px;
  border: 1px solid #f0f0f0;
}

.detail-title {
  font-size: 16px;
  font-weight: 600;
  margin-bottom: 12px;
  color: #262626;
}

.metadata-grid {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.metadata-item {
  display: flex;
  gap: 8px;
  font-size: 14px;
}

.metadata-item .label {
  color: #8c8c8c;
  min-width: 70px;
}

.metadata-item .value {
  color: #262626;
}

.metadata-item .value.txid {
  font-family: 'Monaco', 'Menlo', monospace;
  font-size: 12px;
  color: #1890ff;
  word-break: break-all;
}

.pane-content {
  margin-top: 12px;
}

.first-version-hint {
  padding: 40px 0;
}

.empty-detail {
  display: flex;
  justify-content: center;
  align-items: center;
  height: 100%;
  color: #999;
}

/* 响应式 */
@media (max-width: 768px) {
  .timeline-layout {
    flex-direction: column;
  }
  
  .timeline-side {
    border-right: none;
    border-bottom: 1px solid #f0f0f0;
    margin-bottom: 24px;
    max-height: 30vh;
  }
}
</style>
