<script setup lang="ts">
import type { MenuCategory } from '../data/menu'

defineProps<{ categories: MenuCategory[]; activeCategory: string }>()
defineEmits<{ select: [categoryId: string] }>()
</script>

<template>
  <nav class="category-nav" aria-label="Secciones de la carta">
    <button
      v-for="category in categories"
      :key="category.id"
      class="category-link"
      :class="{ 'is-active': activeCategory === category.id }"
      type="button"
      @click="$emit('select', category.id)"
    >
      <span class="category-icon" aria-hidden="true">{{ category.icon }}</span>
      <span>{{ category.name }}</span>
    </button>
  </nav>
</template>
