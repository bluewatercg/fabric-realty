<template>
  <div class="oem-page">
    <a-page-header
      title="主机厂 (OEM)"
      sub-title="发布采购订单并确认收货"
      @back="() => $router.push('/')"
    >
      <template #extra>
        <a-button type="primary" @click="showCreateModal = true">
          <PlusOutlined /> 创建订单
        </a-button>
      </template>
    </a-page-header>

    <div class="content">
      <!-- 订单列表 -->
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
                  v-if="record.status === 'SHIPPED' || record.status === 'DELIVERED'"
                  type="primary"
                  size="small"
                  @click="confirmReceipt(record.id)"
                >
                  确认收货
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

    <!-- 创建订单弹窗 -->
    <a-modal
      v-model:open="showCreateModal"
      title="创建采购订单"
      @ok="handleCreateOrder"
      @cancel="resetForm"
      width="600px"
    >
      <a-form :model="orderForm" layout="vertical">
        <a-form-item label="订单ID" required>
          <a-input v-model:value="orderForm.id" placeholder="请输入订单ID" />
        </a-form-item>
        <a-form-item label="零部件厂商ID" required>
          <a-input v-model:value="orderForm.manufacturerId" placeholder="请输入厂商ID" />
        </a-form-item>
        <a-form-item label="零件清单">
          <div v-for="(item, index) in orderForm.items" :key="index" class="item-row">
            <a-input
              v-model:value="item.name"
              placeholder="零件名称"
              style="width: 35%"
            />
            <a-input-number
              v-model:value="item.quantity"
              placeholder="数量"
              :min="1"
              style="width: 25%"
            />
            <a-input-number
              v-model:value="item.price"
              placeholder="单价"
              :min="0"
              :precision="2"
              style="width: 25%"
            />
            <a-button danger @click="removeItem(index)" v-if="orderForm.items.length > 1">
              删除
            </a-button>
          </div>
          <a-button type="dashed" @click="addItem" style="width: 100%; margin-top: 10px">
            <PlusOutlined /> 添加零件
          </a-button>
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 订单详情弹窗 -->
    <a-modal
      v-model:open="showDetailModal"
      title="订单详情"
      :footer="null"
      width="600px"
    >
      <a-descriptions bordered v-if="selectedOrder">
        <a-descriptions-item label="订单ID">{{ selectedOrder.id }}</a-descriptions-item>
        <a-descriptions-item label="厂商ID">{{ selectedOrder.manufacturerId }}</a-descriptions-item>
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
import { PlusOutlined } from '@ant-design/icons-vue';
import { supplyChainApi } from '../api';
import type { Order, OrderItem } from '../types';

const loading = ref(false);
const orders = ref<Order[]>([]);
const bookmark = ref('');
const showCreateModal = ref(false);
const showDetailModal = ref(false);
const selectedOrder = ref<Order | null>(null);

const orderForm = ref({
  id: '',
  manufacturerId: '',
  items: [{ name: '', quantity: 1, price: 0 }] as OrderItem[]
});

const columns = [
  { title: '订单ID', dataIndex: 'id', key: 'id' },
  { title: '厂商ID', dataIndex: 'manufacturerId', key: 'manufacturerId' },
  { title: '状态', key: 'status' },
  { title: '总价', key: 'totalPrice' },
  { title: '创建时间', dataIndex: 'createTime', key: 'createTime' },
  { title: '操作', key: 'action', width: 200 }
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
      'OEM'
    );
    orders.value.push(...result.records);
    bookmark.value = result.bookmark;
  } catch (error: any) {
    message.error('加载订单失败: ' + (error.message || '未知错误'));
  } finally {
    loading.value = false;
  }
};

const handleCreateOrder = async () => {
  if (!orderForm.value.id || !orderForm.value.manufacturerId) {
    message.warning('请填写订单ID和厂商ID');
    return;
  }

  if (orderForm.value.items.some(item => !item.name || item.quantity <= 0 || item.price <= 0)) {
    message.warning('请完整填写零件信息');
    return;
  }

  try {
    await supplyChainApi.createOrder({
      id: orderForm.value.id,
      manufacturerId: orderForm.value.manufacturerId,
      items: orderForm.value.items
    });
    message.success('订单创建成功');
    showCreateModal.value = false;
    resetForm();
    // 重新加载订单列表
    orders.value = [];
    bookmark.value = '';
    await loadOrders();
  } catch (error: any) {
    message.error('创建订单失败: ' + (error.message || '未知错误'));
  }
};

const confirmReceipt = async (orderId: string) => {
  try {
    await supplyChainApi.receiveOrder(orderId);
    message.success('确认收货成功');
    // 重新加载订单列表
    orders.value = [];
    bookmark.value = '';
    await loadOrders();
  } catch (error: any) {
    message.error('确认收货失败: ' + (error.message || '未知错误'));
  }
};

const viewOrder = (order: Order) => {
  selectedOrder.value = order;
  showDetailModal.value = true;
};

const addItem = () => {
  orderForm.value.items.push({ name: '', quantity: 1, price: 0 });
};

const removeItem = (index: number) => {
  orderForm.value.items.splice(index, 1);
};

const resetForm = () => {
  orderForm.value = {
    id: '',
    manufacturerId: '',
    items: [{ name: '', quantity: 1, price: 0 }]
  };
};

onMounted(() => {
  loadOrders();
});
</script>

<style scoped>
.oem-page {
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

.item-row {
  display: flex;
  gap: 10px;
  margin-bottom: 10px;
  align-items: center;
}
</style>
