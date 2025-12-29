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

// API 统一响应结构
export interface ApiResponse<T = any> {
  code: number;
  message: string;
  data?: T;
}

// 保持与之前类似的分页结果结构
export interface SupplyChainPageResult<T> {
  records: T[];
  bookmark: string;
  recordsCount: number;
  fetchedRecordsCount: number;
}

// 历史记录相关类型
export interface DiffDetail {
  old: any;
  new: any;
}

export interface HistoryRecord {
  txId: string;
  timestamp: string;
  isDelete: boolean;
  value: any;
  diff: Record<string, DiffDetail>;
}