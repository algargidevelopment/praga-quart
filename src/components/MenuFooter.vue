<script setup lang="ts">
import type { BarProfile } from '../data/menu'

defineProps<{ bar?: BarProfile }>()
</script>

<template>
  <footer class="menu-footer">
    <span class="footer-stars" aria-hidden="true">✦　✦　✦</span>
    <p>{{ bar?.footerText }}</p>
    <small>{{ bar?.footerNote }}</small>
  </footer>
</template>
