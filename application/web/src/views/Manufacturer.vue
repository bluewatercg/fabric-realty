<template>
  <div class="manufacturer-page">
    <a-page-header
      title="零部件厂商 (Manufacturer)"
      sub-title="接受订单并管理生产进度"
      @back="() => $router.push('/')"
    />

    <div class="content">
      <a-card title="订单列表" :loading="loading">
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
                  v-if="record.status === 'CREATED'"
                  type="primary"
                  size="small"
                  @click="acceptOrder(record.id)"
                >
                  接受订单
                </a-button>
                <a-button
                  v-if="['ACCEPTED', 'PRODUCING', 'PRODUCED'].includes(record.status)"
                  type="primary"
                  size="small"
                  @click="showUpdateStatusModal(record)"
                >
                  更新状态
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

    <!-- 更新状态弹窗 -->
    <a-modal
      :visible="showStatusModal"
      title="更新生产状态"
      @ok="handleUpdateStatus"
      @cancel="showStatusModal = false"
    >
      <a-form layout="vertical">
        <a-form-item label="当前订单ID">
          <a-input :value="selectedOrder?.id" disabled />
        </a-form-item>
        <a-form-item label="选择新状态" required>
          <a-select v-model:value="newStatus" placeholder="请选择状态">
            <a-select-option value="PRODUCING">生产中</a-select-option>
            <a-select-option value="PRODUCED">已生产</a-select-option>
            <a-select-option value="READY">待取货</a-select-option>
          </a-select>
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 订单详情弹窗 -->
    <a-modal
      :visible="showDetailModal"
      title="订单详情"
      :footer="null"
      width="600px"
    >
      <a-descriptions bordered v-if="selectedOrder">
        <a-descriptions-item label="订单ID">{{ selectedOrder.id }}</a-descriptions-item>
        <a-descriptions-item label="主机厂ID">{{ selectedOrder.oemId }}</a-descriptions-item>
        <a-descriptions-item label="状态">
          <a-tag :color="getStatusColor(selectedOrder.status)">
            {{ getStatusText(selectedOrder.status) }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="总价">¥{{ selectedOrder.totalPrice.toFixed(2) }}</a-descriptions-item>
        <a-descriptions-item label="创建时间">{{ selectedOrder.createTime }}</a-descriptions-item>
        <a-descriptions-item label="更新时间">{{ selectedOrder.updateTime }}</a-descriptions-item>
        <a-descriptions-item label="零件清单" :span="3">
          <a-table
            :columns="itemColumns"
            :data-source="selectedOrder.items"
            :pagination="false"
            size="small"
          />
        </a-descriptions-item>
      </a-descriptions>
    </a-modal>
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { message } from 'ant-design-vue';
import { supplyChainApi } from '../api';
import type { Order } from '../types';

const loading = ref(false);
const orders = ref<Order[]>([]);
const bookmark = ref('');
const showStatusModal = ref(false);
const showDetailModal = ref(false);
const selectedOrder = ref<Order | null>(null);
const newStatus = ref('');

const columns = [
  { title: '订单ID', dataIndex: 'id', key: 'id' },
  { title: '主机厂ID', dataIndex: 'oemId', key: 'oemId' },
  { title: '状态', key: 'status' },
  { title: '总价', key: 'totalPrice' },
  { title: '创建时间', dataIndex: 'createTime', key: 'createTime' },
  { title: '操作', key: 'action', width: 250 }
];

const itemColumns = [
  { title: '零件名称', dataIndex: 'name', key: 'name' },
  { title: '数量', dataIndex: 'quantity', key: 'quantity' },
  { title: '单价', dataIndex: 'price', key: 'price' }
];

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
      'MANUFACTURER'
    );
    orders.value.push(...result.records);
    bookmark.value = result.bookmark;
  } catch (error: any) {
    message.error('加载订单失败: ' + (error.message || '未知错误'));
  } finally {
    loading.value = false;
  }
};

const acceptOrder = async (orderId: string) => {
  try {
    await supplyChainApi.acceptOrder(orderId);
    message.success('订单接受成功');
    orders.value = [];
    bookmark.value = '';
    await loadOrders();
  } catch (error: any) {
    message.error('接受订单失败: ' + (error.message || '未知错误'));
  }
};

const showUpdateStatusModal = (order: Order) => {
  selectedOrder.value = order;
  newStatus.value = '';
  showStatusModal.value = true;
};

const handleUpdateStatus = async () => {
  if (!newStatus.value) {
    message.warning('请选择新状态');
    return;
  }

  try {
    await supplyChainApi.updateOrderStatus(selectedOrder.value!.id, newStatus.value);
    message.success('状态更新成功');
    showStatusModal.value = false;
    orders.value = [];
    bookmark.value = '';
    await loadOrders();
  } catch (error: any) {
    message.error('更新状态失败: ' + (error.message || '未知错误'));
  }
};

const viewOrder = (order: Order) => {
  selectedOrder.value = order;
  showDetailModal.value = true;
};

onMounted(() => {
  loadOrders();
});
</script>

<style scoped>
.manufacturer-page {
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
