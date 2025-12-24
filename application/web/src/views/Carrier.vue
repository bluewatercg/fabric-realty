<template>
  <div class="carrier-page">
    <a-page-header
      title="承运商 (Carrier)"
      sub-title="物流取货与实时位置更新"
      @back="() => $router.push('/')"
    />

    <div class="content">
      <a-card title="待取货订单" :loading="loading">
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
                  v-if="record.status === 'READY'"
                  type="primary"
                  size="small"
                  @click="showPickupModal(record)"
                >
                  取货
                </a-button>
                <a-button
                  v-if="record.status === 'SHIPPED' && record.shipmentId"
                  type="primary"
                  size="small"
                  @click="showLocationModal(record)"
                >
                  更新位置
                </a-button>
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

    <!-- 取货弹窗 -->
    <a-modal
      :visible="showPickup"
      title="取货并生成物流单"
      :closable="true"
      :maskClosable="false"
      @ok="handlePickup"
      @cancel="showPickup = false"
      @close="showPickup = false"
    >
      <a-form layout="vertical">
        <a-form-item label="订单ID">
          <a-input :value="selectedOrder?.id" disabled />
        </a-form-item>
        <a-form-item label="物流单ID" required>
          <a-input v-model:value="shipmentId" placeholder="请输入物流单ID" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 更新位置弹窗 -->
    <a-modal
      :visible="showLocation"
      title="更新物流位置"
      :closable="true"
      :maskClosable="false"
      @ok="handleUpdateLocation"
      @cancel="showLocation = false"
      @close="showLocation = false"
    >
      <a-form layout="vertical">
        <a-form-item label="物流单ID">
          <a-input :value="selectedOrder?.shipmentId" disabled />
        </a-form-item>
        <a-form-item label="当前位置" required>
          <a-input v-model:value="newLocation" placeholder="请输入当前位置" />
        </a-form-item>
      </a-form>
    </a-modal>

    <!-- 订单详情弹窗 -->
    <a-modal
      :visible="showDetailModal"
      title="订单详情"
      :footer="null"
      :closable="true"
      @close="showDetailModal = false"
      width="600px"
    >
      <a-descriptions bordered v-if="selectedOrder">
        <a-descriptions-item label="订单ID">{{ selectedOrder.id }}</a-descriptions-item>
        <a-descriptions-item label="主机厂ID">{{ selectedOrder.oemId }}</a-descriptions-item>
        <a-descriptions-item label="厂商ID">{{ selectedOrder.manufacturerId }}</a-descriptions-item>
        <a-descriptions-item label="状态">
          <a-tag :color="getStatusColor(selectedOrder.status)">
            {{ getStatusText(selectedOrder.status) }}
          </a-tag>
        </a-descriptions-item>
        <a-descriptions-item label="总价">¥{{ selectedOrder.totalPrice.toFixed(2) }}</a-descriptions-item>
        <a-descriptions-item label="物流单ID">{{ selectedOrder.shipmentId || '未生成' }}</a-descriptions-item>
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

    <!-- 物流详情弹窗 -->
    <a-modal
      :visible="showShipmentModal"
      title="物流详情"
      :footer="null"
      :closable="true"
      @close="showShipmentModal = false"
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
  </div>
</template>

<script setup lang="ts">
import { ref, onMounted } from 'vue';
import { message } from 'ant-design-vue';
import { supplyChainApi } from '../api';
import type { Order, Shipment } from '../types';

const loading = ref(false);
const orders = ref<Order[]>([]);
const bookmark = ref('');
const showPickup = ref(false);
const showLocation = ref(false);
const showDetailModal = ref(false);
const showShipmentModal = ref(false);
const selectedOrder = ref<Order | null>(null);
const currentShipment = ref<Shipment | null>(null);
const shipmentId = ref('');
const newLocation = ref('');

const columns = [
  { title: '订单ID', dataIndex: 'id', key: 'id' },
  { title: '主机厂ID', dataIndex: 'oemId', key: 'oemId' },
  { title: '状态', key: 'status' },
  { title: '总价', key: 'totalPrice' },
  { title: '物流单ID', dataIndex: 'shipmentId', key: 'shipmentId' },
  { title: '操作', key: 'action', width: 300 }
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
      'CARRIER'
    );
    orders.value.push(...result.records);
    bookmark.value = result.bookmark;
  } catch (error: any) {
    message.error('加载订单失败: ' + (error.message || '未知错误'));
  } finally {
    loading.value = false;
  }
};

const showPickupModal = (order: Order) => {
  selectedOrder.value = order;
  shipmentId.value = '';
  showPickup.value = true;
};

const handlePickup = async () => {
  if (!shipmentId.value) {
    message.warning('请输入物流单ID');
    return;
  }

  try {
    await supplyChainApi.pickupGoods({
      orderId: selectedOrder.value!.id,
      shipmentId: shipmentId.value
    });
    message.success('取货成功');
    showPickup.value = false;
    orders.value = [];
    bookmark.value = '';
    await loadOrders();
  } catch (error: any) {
    message.error('取货失败: ' + (error.message || '未知错误'));
  }
};

const showLocationModal = (order: Order) => {
  selectedOrder.value = order;
  newLocation.value = '';
  showLocation.value = true;
};

const handleUpdateLocation = async () => {
  if (!newLocation.value) {
    message.warning('请输入当前位置');
    return;
  }

  try {
    await supplyChainApi.updateLocation(selectedOrder.value!.shipmentId, newLocation.value);
    message.success('位置更新成功');
    showLocation.value = false;
  } catch (error: any) {
    message.error('更新位置失败: ' + (error.message || '未知错误'));
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

onMounted(() => {
  loadOrders();
});
</script>

<style scoped>
.carrier-page {
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
