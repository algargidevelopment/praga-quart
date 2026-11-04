<script setup lang="ts">
import { ref } from 'vue'
import MenuProductRow from './MenuProductRow.vue'
import type { MenuCategory, MenuProduct } from '../data/menu'

const props = defineProps<{
  category: MenuCategory
  products: MenuProduct[]
  quantityFor: (productId: string, formatName: string) => number
  formatPrice: (price: number) => string
}>()
const emit = defineEmits<{
  add: [product: MenuProduct, format: MenuProduct['formats'][number]]
  changeQuantity: [productId: string, formatName: string, change: number]
}>()
const collapsed = ref(false)

function productsFor(subcategoryId: string) {
  return props.products.filter((product) => product.subcategoryId === subcategoryId)
}
</script>

<template>
  <section :id="category.id" class="menu-section" :aria-labelledby="`${category.id}-title`">
    <button
      class="section-heading"
      type="button"
      :aria-expanded="!collapsed"
      :aria-controls="`${category.id}-content`"
      @click="collapsed = !collapsed"
    >
      <span class="section-mark" aria-hidden="true">✳</span>
      <h2 :id="`${category.id}-title`">{{ category.name }}</h2>
      <span class="section-rule" aria-hidden="true"></span>
      <span class="section-toggle" :class="{ 'is-collapsed': collapsed }" aria-hidden="true">⌄</span>
    </button>

    <div :id="`${category.id}-content`" v-show="!collapsed">
      <p v-if="category.note" class="section-note">{{ category.note }}</p>
      <div v-for="subcategory in category.subcategories" :key="subcategory.id" class="menu-subcategory">
        <h3 class="subcategory-heading">{{ subcategory.name }}</h3>
        <MenuProductRow
          v-for="product in productsFor(subcategory.id)"
          :key="product.id"
          :product="product"
          :subcategory-name="subcategory.name"
          :quantity-for="quantityFor"
          :format-price="formatPrice"
          @add="(format) => emit('add', product, format)"
          @change-quantity="(formatName, change) => emit('changeQuantity', product.id, formatName, change)"
        />
        <p v-if="productsFor(subcategory.id).length === 0" class="empty-category">
          Pronto añadiremos productos a esta sección.
        </p>
      </div>
    </div>
  </section>
</template>
