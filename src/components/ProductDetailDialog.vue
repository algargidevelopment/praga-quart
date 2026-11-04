<script setup lang="ts">
import type { MenuProduct } from '../data/menu'

defineProps<{
  product: MenuProduct
  formatPrice: (price: number) => string
  quantityFor: (productId: string, formatName: string) => number
}>()
defineEmits<{
  close: []
  add: [format: MenuProduct['formats'][number]]
  changeQuantity: [formatName: string, change: number]
}>()
</script>

<template>
  <div class="product-detail-overlay" @click.self="$emit('close')" @keydown.esc="$emit('close')">
    <section class="product-detail-dialog" :class="{ 'has-image': product.image }" role="dialog" aria-modal="true" aria-labelledby="product-detail-title">
      <button class="product-detail-close" type="button" aria-label="Cerrar detalles" @click="$emit('close')">×</button>
      <img v-if="product.image" class="product-detail-image" :src="product.image" :alt="product.name" />
      <div class="product-detail-content">
        <p class="eyebrow">DETALLES DEL PRODUCTO</p>
        <h2 id="product-detail-title">{{ product.name }}</h2>
        <p class="product-detail-description">{{ product.detailedDescription || product.description || 'Consulta con nuestro equipo si necesitas más información sobre este producto.' }}</p>
        <div v-if="product.formats.length" class="product-detail-formats">
          <div v-for="format in product.formats" :key="format.id" class="product-detail-format">
            <div class="product-detail-format-copy">
              <span>{{ format.name }}</span>
              <strong>{{ formatPrice(format.price) }}</strong>
            </div>
            <div class="quantity-control product-detail-quantity" :aria-label="`${format.name}: ${quantityFor(product.id, format.name)} unidades`">
              <button type="button" :aria-label="`Quitar una unidad de ${product.name}, ${format.name}`" :disabled="quantityFor(product.id, format.name) === 0" @click="$emit('changeQuantity', format.name, -1)">−</button>
              <span>{{ quantityFor(product.id, format.name) }}</span>
              <button type="button" :aria-label="`Añadir una unidad de ${product.name}, ${format.name}`" @click="$emit('add', format)">+</button>
            </div>
          </div>
        </div>
      </div>
    </section>
  </div>
</template>
