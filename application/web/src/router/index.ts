import { createRouter, createWebHistory } from 'vue-router'

const router = createRouter({
  history: createWebHistory(),
  routes: [
    {
      path: '/',
      component: () => import('../views/Home.vue'),
    },
    {
      path: '/oem',
      component: () => import('../views/OEM.vue'),
    },
    {
      path: '/manufacturer',
      component: () => import('../views/Manufacturer.vue'),
    },
    {
      path: '/carrier',
      component: () => import('../views/Carrier.vue'),
    },
    {
      path: '/platform',
      component: () => import('../views/Platform.vue'),
    },
  ],
})

export default router 