<script setup lang="ts">
import { ref } from 'vue'
import type { CartLine } from '../types/cart'

const confirmingOrder = ref(false)
const orderConfirmed = ref(false)
const isSubmitting = ref(false)
const orderError = ref('')
const orderId = ref('')

const props = defineProps<{
  cart: CartLine[]
  total: number
  formatPrice: (price: number) => string
  tableLabel?: string
  canConfirm: boolean
  confirmOrder: () => Promise<{ order_id: string; total: number }>
}>()
defineEmits<{
  close: []
  changeQuantity: [line: CartLine, change: number]
  clear: []
}>()

async function submitOrder() {
  isSubmitting.value = true
  orderError.value = ''
  try {
    const order = await props.confirmOrder()
    orderId.value = order.order_id
    orderConfirmed.value = true
  } catch (error) {
    console.error('No se pudo guardar el pedido:', error)
    orderError.value = 'No se pudo guardar el pedido. Comprueba la conexión e inténtalo de nuevo.'
  } finally {
    isSubmitting.value = false
  }
}
</script>

<template>
  <div class="cart-overlay" @click.self="$emit('close')">
    <section class="cart-panel" role="dialog" aria-modal="true" aria-labelledby="cart-title">
      <header class="cart-panel-header">
        <div>
          <p class="eyebrow">PRAGA QUART</p>
          <h2 id="cart-title">Tu cesta</h2>
        </div>
        <button class="close-cart" type="button" aria-label="Cerrar cesta" @click="$emit('close')">
          <span aria-hidden="true">×</span>
        </button>
      </header>
      <p v-if="cart.length === 0" class="empty-cart">Tu cesta está vacía.</p>
      <div v-else class="cart-lines">
        <article v-for="line in cart" :key="line.formatId" class="cart-line">
          <div class="cart-line-copy">
            <strong>{{ line.productName }}</strong>
            <span>{{ line.formatName }} · {{ formatPrice(line.price) }}</span>
          </div>
          <div class="quantity-control" :aria-label="`Cantidad: ${line.quantity}`">
            <button type="button" :aria-label="`Quitar una unidad de ${line.productName}`" @click="$emit('changeQuantity', line, -1)">−</button>
            <span>{{ line.quantity }}</span>
            <button type="button" :aria-label="`Añadir una unidad de ${line.productName}`" @click="$emit('changeQuantity', line, 1)">+</button>
          </div>
        </article>
      </div>
      <footer v-if="cart.length > 0" class="cart-summary">
        <button class="clear-cart" type="button" @click="$emit('clear')">Vaciar cesta</button>
        <div class="cart-total">
          <span>Total</span>
          <strong>{{ formatPrice(total) }}</strong>
        </div>
        <p v-if="!canConfirm" class="table-required">Escanea el QR de una mesa para poder confirmar.</p>
        <button class="confirm-order" type="button" :disabled="!canConfirm" @click="confirmingOrder = true">Confirmar pedido</button>
      </footer>

      <div v-if="confirmingOrder" class="order-confirm-overlay" @click.self="confirmingOrder = false">
        <section class="order-confirm-dialog" role="alertdialog" aria-modal="true" aria-labelledby="order-confirm-title" aria-describedby="order-confirm-description">
          <template v-if="!orderConfirmed">
            <p class="eyebrow">PRAGA QUART</p>
            <h3 id="order-confirm-title">¿Confirmamos tu pedido?</h3>
            <p id="order-confirm-description">Vas a pedir {{ cart.reduce((sum, line) => sum + line.quantity, 0) }} artículos para la mesa <strong>{{ tableLabel }}</strong> por un total aproximado de <strong>{{ formatPrice(total) }}</strong>.</p>
            <p v-if="orderError" class="order-error" role="alert">{{ orderError }}</p>
            <div class="order-confirm-actions">
              <button class="order-cancel" type="button" :disabled="isSubmitting" @click="confirmingOrder = false">Seguir revisando</button>
              <button class="confirm-order" type="button" :disabled="isSubmitting" @click="submitOrder">{{ isSubmitting ? 'Guardando…' : 'Sí, confirmar' }}</button>
            </div>
          </template>
          <template v-else>
            <p class="eyebrow">PEDIDO CONFIRMADO</p>
            <h3 id="order-confirm-title">¡Gracias!</h3>
            <p id="order-confirm-description">Tu pedido se ha guardado correctamente con el número <strong>{{ orderId }}</strong>.</p>
            <button class="confirm-order" type="button" @click="$emit('close')">Volver a la carta</button>
          </template>
        </section>
      </div>
    </section>
  </div>
</template>
