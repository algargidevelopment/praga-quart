<script setup lang="ts">
import { computed, onMounted, ref } from 'vue'
import CategoryNav from './components/CategoryNav.vue'
import CartBar from './components/CartBar.vue'
import CartPanel from './components/CartPanel.vue'
import MenuFooter from './components/MenuFooter.vue'
import MenuIntro from './components/MenuIntro.vue'
import MenuSection from './components/MenuSection.vue'
import SiteHeader from './components/SiteHeader.vue'
import { fetchMenu, resolveDiningTable, submitOrder } from './data/menuRepository'
import type { BarProfile, MenuCategory, MenuProduct } from './data/menu'
import type { CartLine } from './types/cart'

const menuCategories = ref<MenuCategory[]>([])
const menuProducts = ref<MenuProduct[]>([])
const bar = ref<BarProfile>()
const isLoading = ref(true)
const menuError = ref('')
const tableError = ref('')
const diningTable = ref<{ id: string; label: string; code: string }>()
const cart = ref<CartLine[]>([])
const cartOpen = ref(false)
const activeCategory = ref('')
const itemCount = computed(() => cart.value.reduce((sum, line) => sum + line.quantity, 0))
const cartTotal = computed(() => cart.value.reduce((sum, line) => sum + line.price * line.quantity, 0))

async function loadMenu() {
  try {
    const barSlug = import.meta.env.VITE_BAR_SLUG || 'praga-quart'
    const menu = await fetchMenu(barSlug)
    bar.value = menu.bar
    menuCategories.value = menu.categories
    menuProducts.value = menu.products
    activeCategory.value = menu.categories[0]?.id ?? ''
    const tableCode = new URLSearchParams(window.location.search).get('mesa')?.trim()
    if (tableCode) {
      try {
        const table = await resolveDiningTable(menu.bar.id, tableCode)
        diningTable.value = { ...table, code: tableCode }
      } catch (error) {
        console.error('No se pudo validar la mesa del QR:', error)
        tableError.value = 'No se ha podido identificar esta mesa. Escanea de nuevo el QR o avisa al personal.'
      }
    }
  } catch (error) {
    console.error('No se pudo cargar la carta desde Supabase:', error)
    menuError.value = 'No se pudo cargar la carta. Comprueba la conexión e inténtalo de nuevo.'
  } finally {
    isLoading.value = false
  }
}

onMounted(loadMenu)

function addToCart(product: MenuProduct, format: MenuProduct['formats'][number]) {
  const line = cart.value.find((item) => item.productId === product.id && item.formatName === format.name)
  if (line) {
    line.quantity += 1
    return
  }
  cart.value.push({ productId: product.id, formatId: format.id, productName: product.name, formatName: format.name, price: format.price, quantity: 1 })
}

function changeQuantity(line: CartLine, change: number) {
  line.quantity += change
  if (line.quantity <= 0) cart.value = cart.value.filter((item) => item !== line)
}

function changeProductQuantity(productId: string, formatName: string, change: number) {
  const line = cart.value.find((item) => item.productId === productId && item.formatName === formatName)
  if (line) changeQuantity(line, change)
}

function quantityFor(productId: string, formatName: string) {
  return cart.value.find((item) => item.productId === productId && item.formatName === formatName)?.quantity ?? 0
}

function scrollToCategory(categoryId: string) {
  activeCategory.value = categoryId
  document.getElementById(categoryId)?.scrollIntoView({ behavior: 'smooth', block: 'start' })
}

function formatPrice(price: number) {
  return new Intl.NumberFormat('es-ES', { style: 'currency', currency: 'EUR' }).format(price)
}

async function confirmOrder() {
  if (!diningTable.value) throw new Error('No hay una mesa válida asociada a este pedido.')
  const order = await submitOrder(
    import.meta.env.VITE_BAR_SLUG || 'praga-quart',
    diningTable.value.code,
    cart.value.map((line) => ({ formatId: line.formatId, quantity: line.quantity })),
  )
  cart.value = []
  return order
}
</script>

<template>
  <div class="menu-app" :class="{ 'has-cart': itemCount > 0 }">
    <SiteHeader :bar="bar" :item-count="itemCount" @open-cart="cartOpen = true" />
    <main id="top">
      <MenuIntro :bar="bar" />
      <p
        v-if="!isLoading && !menuError"
        class="table-status"
        :class="diningTable ? 'is-identified' : tableError ? 'is-error' : 'is-unassigned'"
        :role="tableError ? 'alert' : 'status'"
      >
        <template v-if="diningTable">Mesa {{ diningTable.label }}</template>
        <template v-else-if="tableError">No se pudo validar esta mesa · escanea de nuevo el QR</template>
        <template v-else>Sin mesa · escanea el QR de tu mesa para pedir</template>
      </p>
      <CategoryNav
        v-if="menuCategories.length > 0"
        :categories="menuCategories"
        :active-category="activeCategory"
        @select="scrollToCategory"
      />
      <p v-if="isLoading" class="menu-status" role="status">Cargando la carta…</p>
      <p v-else-if="menuError" class="menu-status menu-error" role="alert">{{ menuError }}</p>
      <p v-else-if="menuCategories.length === 0" class="menu-status" role="status">La carta todavía no tiene categorías.</p>
      <div class="menu-content">
        <MenuSection
          v-for="category in menuCategories"
          :key="category.id"
          :category="category"
          :products="menuProducts"
          :quantity-for="quantityFor"
          :format-price="formatPrice"
          @add="addToCart"
          @change-quantity="changeProductQuantity"
        />
      </div>
      <MenuFooter :bar="bar" />
    </main>
    <CartBar v-if="itemCount > 0" :item-count="itemCount" :total="cartTotal" :format-price="formatPrice" @open="cartOpen = true" />
    <CartPanel
      v-if="cartOpen"
      :cart="cart"
      :total="cartTotal"
      :format-price="formatPrice"
      :table-label="diningTable?.label"
      :can-confirm="Boolean(diningTable)"
      :confirm-order="confirmOrder"
      @close="cartOpen = false"
      @change-quantity="changeQuantity"
      @clear="cart = []"
    />
  </div>
</template>
