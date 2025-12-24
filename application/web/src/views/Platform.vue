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
            <a-statistic
              title="总订单数"
              :value="stats.total"
              :value-style="{ color: '#1890ff' }"
            />
          </a-col>
          <a-col :span="6">
            <a-statistic
              title="进行中"
              :value="stats.inProgress"
              :value-style="{ color: '#faad14' }"
            />
          </a-col>
          <a-col :span="6">
            <a-statistic
              title="运输中"
              :value="stats.shipping"
              :value-style="{ color: '#722ed1' }"
            />
          </a-col>
          <a-col :span="6">
            <a-statistic
              title="已完成"
              :value="stats.completed"
              :value-style="{ color: '#52c41a' }"
            />
          </a-col>
        </a-row>

        <!-- 订单列表 -->
        <a-table
          :columns="columns"
          :data-source="orders"
          :pagination="false"
          row-key="id"
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
                  @click="viewShipment(record.shipmentId)"
                >
                  查看物流
                </a-button>
              </a-space>
            </template>
          </template>
        </a-table>

        <div class="pagination" v-if="orders.length > 0">
          <a-button @click="loadOrders()" :disabled="!bookmark">加载更多</a-button>
        </div>
      </a-card>
    </div>

    <!-- 订单详情弹窗 -->
    <a-modal
      :visible="showDetailModal"
      title="订单详情"
      :footer="null"
      :closable="true"
      @cancel="showDetailModal = false"
      width="700px"
    >
      <a-descriptions bordered v-if="selectedOrder" :column="2">
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
          />
        </a-descriptions-item>
      </a-descriptions>
      <div style="text-align: right; margin-top: 24px;">
        <a-button key="history" type="primary" @click="viewHistory(selectedOrder!.id)">查看历史记录</a-button>
      </div>
    </a-modal>

    <!-- 物流详情弹窗 -->
    <a-modal
      :visible="showShipmentModal"
      title="物流详情"
      :footer="null"
      :closable="true"
      @cancel="showShipmentModal = false"
    >
      <a-descriptions bordered v-if="currentShipment">
        <a-descriptions-item label="物流单ID">{{ currentShipment.id }}</a-descriptions-item>
        <a-descriptions-item label="订单ID">{{ currentShipment.orderId }}</a-descriptions-item>
        <a-descriptions-item label="承运商ID">{{ currentShipment.carrierId }}</a-descriptions-item>
        <a-descriptions-item label="当前位置">{{ currentShipment.location }}</a-descriptions-item>
        <a-descriptions-item label="状态">{{ currentShipment.status }}</a-descriptions-item>
        <a-descriptions-item label="更新时间">{{ currentShipment.updateTime }}</a-descriptions-item>
      </a-descriptions>
    </a-modal>

    <!-- 订单历史弹窗 -->
    <a-modal
      :visible="showHistoryModal"
      title="订单历史记录"
      :footer="null"
      :closable="true"
      @cancel="showHistoryModal = false"
      width="900px"
    >
      <a-table
        :columns="historyColumns"
        :data-source="orderHistory"
        :loading="historyLoading"
        row-key="txId"
        size="small"
      >
        <template #bodyCell="{ column, record }">
            <template v-if="column.key === 'isDelete'">
              <a-tag :color="record.isDelete ? 'red' : 'green'">
                {{ record.isDelete ? '删除' : '更新/创建' }}
              </a-tag>
            </template>
            <template v-if="column.key === 'status'">
              <a-tag :color="getStatusColor(record.status)">
                {{ getStatusText(record.status) }}
              </a-tag>
            </template>
        </template>
      </a-table>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted, computed } from 'vue';
import { message } from 'ant-design-vue';
import { supplyChainApi } from '../api';
import type { Order, Shipment } from '../types';

const loading = ref(false);
const orders = ref<Order[]>([]);
const bookmark = ref('');
const showDetailModal = ref(false);
const showShipmentModal = ref(false);
const selectedOrder = ref<Order | null>(null);
const currentShipment = ref<Shipment | null>(null);

const showHistoryModal = ref(false);
const historyLoading = ref(false);
const orderHistory = ref<any[]>([]);

const columns = [
  { title: '订单ID', dataIndex: 'id', key: 'id', width: 120 },
  { title: '主机厂', dataIndex: 'oemId', key: 'oemId', width: 100 },
  { title: '厂商', dataIndex: 'manufacturerId', key: 'manufacturerId', width: 100 },
  { title: '状态', key: 'status', width: 100 },
  { title: '总价', key: 'totalPrice', width: 100 },
  { title: '物流单ID', dataIndex: 'shipmentId', key: 'shipmentId', width: 120 },
  { title: '创建时间', dataIndex: 'createTime', key: 'createTime', width: 180 },
  { title: '操作', key: 'action', width: 180 }
];

const itemColumns = [
  { title: '零件名称', dataIndex: 'name', key: 'name' },
  { title: '数量', dataIndex: 'quantity', key: 'quantity' },
  { title: '单价', dataIndex: 'price', key: 'price' }
];

const historyColumns = [
  { title: '交易ID', dataIndex: 'txId', key: 'txId', ellipsis: true },
  { title: '时间戳', dataIndex: 'timestamp', key: 'timestamp', width: 200 },
  { title: '状态', dataIndex: ['value', 'status'], key: 'status', width: 120 },
  { title: '操作类型', dataIndex: 'isDelete', key: 'isDelete', width: 120 },
];

// 计算统计数据
const stats = computed(() => {
  const total = orders.value.length;
  const inProgress = orders.value.filter(o => 
    ['CREATED', 'ACCEPTED', 'PRODUCING', 'PRODUCED', 'READY'].includes(o.status)
  ).length;
  const shipping = orders.value.filter(o => 
    ['SHIPPED', 'DELIVERED'].includes(o.status)
  ).length;
  const completed = orders.value.filter(o => o.status === 'RECEIVED').length;

  return { total, inProgress, shipping, completed };
});

const getStatusColor = (status: string) => {
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

const getStatusText = (status: string) => {
  const textMap: Record<string, string> = {
    CREATED: '已创建',
    ACCEPTED: '已接受',
    PRODUCING: '生产中',
    PRODUCED: '已生产',
    READY: '待取货',
    SHIPPED: '运输中',
    DELIVERED: '已送达',
    RECEIVED: '已签收'
  };
  return textMap[status] || status;
};

const loadOrders = async () => {
  loading.value = true;
  try {
    const result = await supplyChainApi.getOrderList(
      { pageSize: 10, bookmark: bookmark.value },
      'PLATFORM'
    );
    orders.value.push(...result.records);
    bookmark.value = result.bookmark;
  } catch (error: any) {
    message.error('加载订单失败: ' + (error.message || '未知错误'));
  } finally {
    loading.value = false;
  }
};

const viewOrder = (order: Order) => {
  selectedOrder.value = order;
  showDetailModal.value = true;
};

const viewShipment = async (shipmentId: string) => {
  try {
    currentShipment.value = await supplyChainApi.getShipment(shipmentId);
    showShipmentModal.value = true;
  } catch (error: any) {
    message.error('查询物流失败: ' + (error.message || '未知错误'));
  }
};

const viewHistory = async (orderId: string) => {
  historyLoading.value = true;
  showHistoryModal.value = true;
  try {
    // 从链码返回的记录中，status 在 value 对象里
    const rawHistory = await supplyChainApi.getOrderHistory(orderId);
    orderHistory.value = rawHistory.map(rec => ({
      ...rec,
      status: rec.value?.status || ''
    }));
  } catch (error: any) {
    message.error('加载历史记录失败: ' + (error.message || '未知错误'));
    showHistoryModal.value = false; // Close modal on error
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
}

.pagination {
  margin-top: 16px;
  text-align: center;
}
</style>
