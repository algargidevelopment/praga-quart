<script setup lang="ts">
import { ref } from 'vue'
import type { MenuProduct } from '../data/menu'

const props = defineProps<{
  product: MenuProduct
  subcategoryName: string
  quantityFor: (productId: string, formatName: string) => number
  formatPrice: (price: number) => string
}>()
const emit = defineEmits<{
  add: [format: MenuProduct['formats'][number]]
  changeQuantity: [formatName: string, change: number]
  details: [product: MenuProduct]
}>()
const imageFailed = ref(false)
const imageUrl = props.product.image
  ? props.product.image.startsWith('http')
    ? props.product.image
    : `${import.meta.env.BASE_URL}${props.product.image.replace(/^\/+/, '')}`
  : ''
</script>

<template>
  <article class="product-row" :class="{ 'has-image': product.image && !imageFailed }">
    <button class="product-info product-detail-trigger" type="button" :aria-label="`Ver detalles de ${product.name}`" @click="emit('details', product)">
      <img
        v-if="product.image && !imageFailed"
        class="product-photo"
        :src="imageUrl"
        :alt="product.name"
        loading="lazy"
        @error="imageFailed = true"
      />
      <div class="product-copy">
        <h4>{{ product.name }}</h4>
        <p v-if="product.description && !subcategoryName.toLocaleLowerCase().startsWith(product.description.toLocaleLowerCase())">
          {{ product.description }}
        </p>
      </div>
    </button>
    <div class="product-formats">
      <div v-for="format in product.formats" :key="format.name" class="format-action">
        <button
          v-if="quantityFor(product.id, format.name) === 0"
          class="format-button"
          type="button"
          :aria-label="`Añadir ${product.name}, ${format.name}, ${formatPrice(format.price)}`"
          @click="emit('add', format)"
        >
          <span class="format-copy">
            <span class="format-name">{{ format.name }}</span>
            <strong>{{ formatPrice(format.price) }}</strong>
          </span>
          <span class="add-mark" aria-hidden="true">+</span>
        </button>
        <div v-else class="product-quantity" :aria-label="`${format.name}: ${quantityFor(product.id, format.name)} unidades`">
          <span class="product-quantity-name">{{ format.name }}</span>
          <button type="button" :aria-label="`Quitar una unidad de ${product.name}, ${format.name}`" @click="emit('changeQuantity', format.name, -1)">−</button>
          <strong>{{ quantityFor(product.id, format.name) }}</strong>
          <button type="button" :aria-label="`Añadir una unidad de ${product.name}, ${format.name}`" @click="emit('changeQuantity', format.name, 1)">+</button>
          <span class="product-quantity-price">{{ formatPrice(format.price) }}</span>
        </div>
      </div>
    </div>
  </article>
</template>
