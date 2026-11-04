<script setup lang="ts">
import type { BarProfile } from '../data/menu'

defineProps<{ itemCount: number; bar?: BarProfile }>()
defineEmits<{ openCart: [] }>()
</script>

<template>
  <header class="site-header">
    <a class="brand" href="#top" :aria-label="`${bar?.name ?? 'Bar'}, inicio`">
      <span class="brand-stars" aria-hidden="true">★ ★ ★</span>
      <span class="brand-name">{{ bar?.name ?? 'Carta' }}</span>
      <span class="brand-caption">{{ bar?.typeLabel }}</span>
    </a>
    <button class="header-cart" type="button" aria-label="Abrir cesta" @click="$emit('openCart')">
      <span class="cart-glyph" aria-hidden="true">▤</span>
      <span class="header-cart-count">{{ itemCount }}</span>
    </button>
  </header>
</template>
