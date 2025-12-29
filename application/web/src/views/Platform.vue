<template>
  <div class="platform-page">
    <a-page-header
      title="物流平台 (Platform)"
      sub-title="撮合管理与供应链全景监管"
      @back="() => $router.push('/')"
    />

    <div class="content">
      <a-card title="全部订单监管" :loading="loading">
        <!-- 统计卡片 -->
        <a-row :gutter="16" style="margin-bottom: 24px">
          <a-col :span="6">
            <a-statistic title="总订单数" :value="stats.total" value-style="{ color: '#1890ff' }" />
          </a-col>
          <a-col :span="6">
            <a-statistic title="进行中" :value="stats.inProgress" value-style="{ color: '#faad14' }" />
          </a-col>
          <a-col :span="6">
            <a-statistic title="运输中" :value="stats.shipping" value-style="{ color: '#722ed1' }" />
          </a-col>
          <a-col :span="6">
            <a-statistic title="已完成" :value="stats.completed" value-style="{ color: '#52c41a' }" />
          </a-col>
        </a-row>

        <!-- 订单列表 -->
        <a-table
          :columns="columns"
          :data-source="orders"
          :pagination="false"
          row-key="id"
          :scroll="{ x: 1000 }"
        >
          <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'status'">
              <a-tag :color="getStatusColor(record.status)">
                {{ getStatusText(record.status) }}
              </a-tag>
            </template>
            <template v-else-if="column.key === 'totalPrice'">
              ¥{{ record.totalPrice.toFixed(2) }}
            </template>
            <template v-else-if="column.key === 'action'">
              <a-space>
                <a-button size="small" @click="viewOrder(record)">查看详情</a-button>
                <a-button
                  v-if="record.shipmentId"
                  size="small"
                  type="link"
                  @click="viewShipment(record.shipmentId)"
                >
                  查看物流
                </a-button>
              </a-space>
            </template>
          </template>
        </a-table>

        <!-- 加载更多 -->
        <div class="pagination" v-if="bookmark">
          <a-button @click="loadOrders" :loading="loading">加载更多</a-button>
        </div>
        <div class="pagination" v-else-if="orders.length > 0">
          <span style="color: #999">已加载全部订单</span>
        </div>
      </a-card>
    </div>

    <!-- 订单详情弹窗 -->
    <a-modal
      v-model:visible="showDetailModal"
      title="订单详情"
      width="800px"
    >
      <a-descriptions bordered :column="2" v-if="selectedOrder">
        <a-descriptions-item label="订单ID">{{ selectedOrder.id }}</a-descriptions-item>
        <a-descriptions-item label="状态">
          <a-tag :color="getStatusColor(selectedOrder.status)">
            {{ getStatusText(selectedOrder.status) }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="主机厂ID">{{ selectedOrder.oemId }}</a-descriptions-item>
        <a-descriptions-item label="厂商ID">{{ selectedOrder.manufacturerId }}</a-descriptions-item>
        <a-descriptions-item label="总价">¥{{ selectedOrder.totalPrice.toFixed(2) }}</a-descriptions-item>
        <a-descriptions-item label="物流单ID">{{ selectedOrder.shipmentId || '未生成' }}</a-descriptions-item>
        <a-descriptions-item label="创建时间" :span="2">{{ selectedOrder.createTime }}</a-descriptions-item>
        <a-descriptions-item label="更新时间" :span="2">{{ selectedOrder.updateTime }}</a-descriptions-item>
        <a-descriptions-item label="零件清单" :span="2">
          <a-table
            :columns="itemColumns"
            :data-source="selectedOrder.items"
            :pagination="false"
            size="small"
            row-key="name"
          />
        </a-descriptions-item>
      </a-descriptions>
      <template #footer>
        <a-button type="primary" @click="viewHistory(selectedOrder!.id)">查看历史记录</a-button>
      </template>
    </a-modal>

    <!-- 物流详情弹窗 -->
    <a-modal
      v-model:visible="showShipmentModal"
      title="物流详情"
      :footer="null"
      width="600px"
    >
      <a-descriptions bordered v-if="currentShipment">
        <a-descriptions-item label="物流单ID">{{ currentShipment.id }}</a-descriptions-item>
        <a-descriptions-item label="订单ID">{{ currentShipment.orderId }}</a-descriptions-item>
        <a-descriptions-item label="承运商ID">{{ currentShipment.carrierId }}</a-descriptions-item>
        <a-descriptions-item label="当前位置">{{ currentShipment.location || '未知' }}</a-descriptions-item>
        <a-descriptions-item label="状态">{{ currentShipment.status }}</a-descriptions-item>
        <a-descriptions-item label="更新时间">{{ currentShipment.updateTime }}</a-descriptions-item>
      </a-descriptions>
    </a-modal>

    <!-- 订单历史记录（Blockchain）弹窗（审计追踪） -->
    <a-modal
      v-model:visible="showHistoryModal"
      title="订单历史记录（Blockchain） (链上审计追踪)"
      :footer="null"
      width="1200px"
      :body-style="{ padding: '24px', maxHeight: '70vh', overflowY: 'auto' }"
    >
      <HistoryTimeline :history="orderHistory" :loading="historyLoading" />
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { message } from 'ant-design-vue';
import { supplyChainApi } from '../api';
import type { Order, Shipment, HistoryRecord } from '../types';
import HistoryTimeline from '../components/HistoryTimeline.vue';

const loading = ref(false);
const orders = ref<Order[]>([]);
const bookmark = ref<string | undefined>('');
const showDetailModal = ref(false);
const showShipmentModal = ref(false);
const showHistoryModal = ref(false);
const selectedOrder = ref<Order | null>(null);
const currentShipment = ref<Shipment | null>(null);
const historyLoading = ref(false);
const orderHistory = ref<HistoryRecord[]>([]);

const columns = [
  { title: '订单ID', dataIndex: 'id', key: 'id', width: 140, fixed: 'left' },
  { title: '主机厂', dataIndex: 'oemId', key: 'oemId', width: 100 },
  { title: '厂商', dataIndex: 'manufacturerId', key: 'manufacturerId', width: 100 },
  { title: '状态', key: 'status', width: 100 },
  { title: '总价', key: 'totalPrice', width: 110 },
  { title: '物流单ID', dataIndex: 'shipmentId', key: 'shipmentId', width: 140 },
  { title: '创建时间', dataIndex: 'createTime', key: 'createTime', width: 180 },
  { title: '操作', key: 'action', width: 180, fixed: 'right' },
];

const itemColumns = [
  { title: '零件名称', dataIndex: 'name', key: 'name' },
  { title: '数量', dataIndex: 'quantity', key: 'quantity', width: 80 },
  { title: '单价', dataIndex: 'price', key: 'price', width: 100 },
];

// 统计数据
const stats = computed(() => {
  const list = orders.value;
  const total = list.length;
  const inProgress = list.filter(o => ['CREATED', 'ACCEPTED', 'PRODUCING', 'PRODUCED', 'READY'].includes(o.status)).length;
  const shipping = list.filter(o => ['SHIPPED', 'DELIVERED'].includes(o.status)).length;
  const completed = list.filter(o => o.status === 'RECEIVED').length;
  return { total, inProgress, shipping, completed };
});

// 状态映射
const statusMap = {
  CREATED: { text: '已创建', color: 'blue' },
  ACCEPTED: { text: '已接受', color: 'cyan' },
  PRODUCING: { text: '生产中', color: 'orange' },
  PRODUCED: { text: '已生产', color: 'purple' },
  READY: { text: '待取货', color: 'geekblue' },
  SHIPPED: { text: '运输中', color: 'gold' },
  DELIVERED: { text: '已送达', color: 'lime' },
  RECEIVED: { text: '已签收', color: 'green' },
};

const getStatusText = (status: string) => statusMap[status]?.text || status;
const getStatusColor = (status: string) => statusMap[status]?.color || 'default';

// 加载订单
const loadOrders = async () => {
  if (loading.value) return;
  loading.value = true;
  try {
    const result = await supplyChainApi.getOrderList(
      { pageSize: 10, bookmark: bookmark.value || undefined },
      'PLATFORM'
    );
    orders.value.push(...result.records);
    bookmark.value = result.bookmark || '';
  } catch (error: any) {
    message.error('加载订单失败: ' + (error.message || '未知错误'));
  } finally {
    loading.value = false;
  }
};

// 查看订单详情
const viewOrder = (order: Order) => {
  selectedOrder.value = order;
  showDetailModal.value = true;
};

// 查看物流
const viewShipment = async (shipmentId: string) => {
  try {
    currentShipment.value = await supplyChainApi.getShipment(shipmentId);
    showShipmentModal.value = true;
  } catch (error: any) {
    message.error('查询物流失败: ' + (error.message || '未知错误'));
  }
};

// 查看历史记录（Blockchain）
const viewHistory = async (orderId: string) => {
  historyLoading.value = true;
  showHistoryModal.value = true;
  try {
    orderHistory.value = await supplyChainApi.getOrderHistory(orderId);
  } catch (error: any) {
    message.error('加载历史记录（Blockchain）失败: ' + (error.message || '未知错误'));
    showHistoryModal.value = false;
  } finally {
    historyLoading.value = false;
  }
};

onMounted(() => {
  loadOrders();
});
</script>

<style scoped>
.platform-page {
  min-height: 100vh;
  background-color: #f0f2f5;
}
.content {
  padding: 24px;
  max-width: 1400px;
  margin: 0 auto;
}
.pagination {
  margin-top: 24px;
  text-align: center;
}
pre {
  background-color: #f5f5f5;
  padding: 12px;
  border-radius: 4px;
  overflow-x: auto;
  font-size: 13px;
}
</style>