<script setup lang="ts">
import type { BarProfile } from '../data/menu'

defineProps<{ bar?: BarProfile }>()
</script>

<template>
  <section class="menu-intro" aria-labelledby="page-title">
    <p class="eyebrow">{{ bar?.introEyebrow }}</p>
    <h1 id="page-title">Nuestra carta</h1>
    <p v-if="bar?.introNote" class="intro-note">{{ bar.introNote }}</p>
  </section>
</template>
