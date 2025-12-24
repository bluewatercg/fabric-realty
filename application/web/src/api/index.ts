import request from '../utils/request';
import type { Order, OrderItem, SupplyChainPageResult } from '../types';

export const supplyChainApi = {
  // 主机厂 (OEM)
  createOrder: (data: { id: string; manufacturerId: string; items: OrderItem[] }) =>
    request.post<never, void>('/oem/order/create', data),

  receiveOrder: (id: string) =>
    request.put<never, void>(`/oem/order/${id}/receive`),

  // 零部件厂商 (Manufacturer)
  acceptOrder: (id: string) =>
    request.put<never, void>(`/manufacturer/order/${id}/accept`),

  updateOrderStatus: (id: string, status: string) =>
    request.put<never, void>(`/manufacturer/order/${id}/status`, { status }),

  // 承运商 (Carrier)
  pickupGoods: (data: { orderId: string; shipmentId: string }) =>
    request.post<never, void>('/carrier/shipment/pickup', data),

  updateLocation: (id: string, location: string) =>
    request.put<never, void>(`/carrier/shipment/${id}/location`, { location }),

  // 通用查询
  getOrder: (id: string) =>
    request.get<never, Order>(`/oem/order/${id}`),

  getOrderList: (params: { pageSize: number; bookmark: string }, role: string) => {
    // 根据角色决定调用的基础路径
    let basePath = '/platform';
    if (role === 'OEM') basePath = '/oem';
    else if (role === 'MANUFACTURER') basePath = '/manufacturer';
    else if (role === 'CARRIER') basePath = '/carrier';

    return request.get<never, SupplyChainPageResult<Order>>(`${basePath}/order/list`, { params });
  },

  getShipment: (id: string) =>
    request.get<never, any>(`/carrier/shipment/${id}`),

  getOrderHistory: (id: string) =>
    request.get<never, any[]>(`/oem/order/${id}/history`)
};
