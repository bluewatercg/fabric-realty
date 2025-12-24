export interface OrderItem {
  name: string;
  quantity: number;
  price: number;
}

export type OrderStatus = 'CREATED' | 'ACCEPTED' | 'PRODUCING' | 'PRODUCED' | 'READY' | 'SHIPPED' | 'DELIVERED' | 'RECEIVED';

export interface Order {
  id: string;
  oemId: string;
  manufacturerId: string;
  items: OrderItem[];
  status: OrderStatus;
  totalPrice: number;
  shipmentId: string;
  createTime: string;
  updateTime: string;
}

export interface Shipment {
  id: string;
  orderId: string;
  carrierId: string;
  location: string;
  status: string;
  updateTime: string;
}

// 保持与之前类似的分页结果结构
export interface SupplyChainPageResult<T> {
  records: T[];
  bookmark: string;
  recordsCount: number;
  fetchedRecordsCount: number;
}

// 保留或清理旧的 Realty 相关类型，取决于用户是否还要它们
// 这里我们为了演示重点，先定义新的