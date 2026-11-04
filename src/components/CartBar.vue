<script setup lang="ts">
defineProps<{ itemCount: number; total: number; formatPrice: (price: number) => string }>()
defineEmits<{ open: [] }>()
</script>

<template>
  <button class="cart-bar" type="button" @click="$emit('open')">
    <span class="cart-bar-count">{{ itemCount }}</span>
    <span>Ver cesta</span>
    <strong>{{ formatPrice(total) }}</strong>
    <span class="cart-arrow" aria-hidden="true">›</span>
  </button>
</template>
