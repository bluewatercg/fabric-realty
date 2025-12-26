<template>
  <div class="home">
    <div class="home-page-header">
      <h1 class="page-title">选择您的组织身份</h1>
      <p class="page-description">本系统由四个组织构成的联盟链网络共同维护</p>
    </div>

    <div class="home-content">
      <router-link to="/oem" class="card">
        <div class="card-icon">
          <SolutionOutlined />
        </div>
        <div class="card-title">主机厂（Org1）</div>
        <div class="card-description">发布采购订单并确认收货</div>
      </router-link>

      <router-link to="/manufacturer" class="card">
        <div class="card-icon">
          <SettingOutlined />
        </div>
        <div class="card-title">零部件厂商（Org2）</div>
        <div class="card-description">接受订单并管理生产进度</div>
      </router-link>

      <router-link to="/carrier" class="card">
        <div class="card-icon">
          <CarOutlined />
        </div>
        <div class="card-title">承运商（Org3）</div>
        <div class="card-description">物流取货与实时位置更新</div>
      </router-link>

      <router-link to="/platform" class="card">
        <div class="card-icon">
          <ClusterOutlined />
        </div>
        <div class="card-title">物流平台（Org3）</div>
        <div class="card-description">撮合管理与供应链全景监管</div>
      </router-link>
    </div>
  </div>
</template>

<script setup lang="ts">
import { SolutionOutlined, CarOutlined, SettingOutlined, ClusterOutlined } from '@ant-design/icons-vue';
</script>

<style scoped>
.home {
  height: 100vh;
  display: flex;
  flex-direction: column;
  background-color: #f0f2f5;
}

.home-content {
  flex: 1;
  display: flex;
  gap: 24px;
  padding: 24px;
}

.card {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 24px;
  border-radius: 8px;
  background-color: #fff;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  transition: all 0.3s;
  cursor: pointer;
  text-decoration: none;
  color: rgba(0, 0, 0, 0.85);
}

.card:hover {
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.12);
  transform: translateY(-2px);
}

.card-icon {
  font-size: 48px;
  margin-bottom: 16px;
  color: #1890ff;
}

.card-title {
  font-size: 18px;
  font-weight: 500;
  margin-bottom: 8px;
  color: rgba(0, 0, 0, 0.85);
}

.card-description {
  font-size: 14px;
  color: rgba(0, 0, 0, 0.45);
  text-align: center;
}

.home-page-header {
  padding: 24px;
  background-color: #fff;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.08);
  text-align: center;
}

.page-title {
  font-size: 28px;
  font-weight: 500;
  color: rgba(0, 0, 0, 0.85);
  margin: 0;
}

.page-description {
  font-size: 16px;
  color: rgba(0, 0, 0, 0.45);
  margin: 8px 0 0 0;
}

@media (max-width: 768px) {
  .home-content {
    flex-direction: column;
  }
}
</style> 