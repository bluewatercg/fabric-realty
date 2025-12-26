<template>
  <div class="json-viewer">
    <pre class="json-content">{{ formattedJson }}</pre>
  </div>
</template>

<script setup lang="ts">
import { computed } from 'vue';

interface Props {
  data: any;
}

const props = defineProps<Props>();

const formattedJson = computed(() => {
  return JSON.stringify(props.data, null, 2);
});
</script>

<style scoped>
.json-viewer {
  background: #f5f5f5;
  border-radius: 4px;
  padding: 12px;
  overflow-x: auto;
  max-height: 500px;
  overflow-y: auto;
}

.json-content {
  margin: 0;
  font-family: 'Monaco', 'Menlo', 'Ubuntu Mono', monospace;
  font-size: 13px;
  line-height: 1.6;
  color: #24292e;
  white-space: pre;
  word-wrap: normal;
  overflow-wrap: normal;
}
</style>
