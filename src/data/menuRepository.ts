import { getSupabaseClient } from '../lib/supabaseClient'
import type { BarProfile, MenuCategory, MenuProduct } from './menu'

interface BarRow {
  id: string
  name: string
  type_label: string
  intro_eyebrow: string
  intro_note: string | null
  footer_text: string | null
  footer_note: string
}

interface CategoryRow {
  bar_id: string
  id: string
  name: string
  icon: string
  note: string | null
  sort_order: number
}

interface SubcategoryRow {
  bar_id: string
  id: string
  category_id: string
  name: string
  sort_order: number
}

interface ProductRow {
  bar_id: string
  id: string
  subcategory_id: string
  name: string
  description: string | null
  detailed_description: string | null
  image_path: string | null
  sort_order: number
  active: boolean
}

interface ProductFormatRow {
  id: string
  bar_id: string
  product_id: string
  name: string
  price: number | string
  sort_order: number
}

export async function fetchMenu(barSlug: string) {
  const supabase = getSupabaseClient()
  const barResult = await supabase
    .from('bars')
    .select('id, name, type_label, intro_eyebrow, intro_note, footer_text, footer_note')
    .eq('slug', barSlug)
    .eq('active', true)
    .single()
  if (barResult.error) throw barResult.error

  const bar = barResult.data as BarRow
  const [categoryResult, subcategoryResult, productResult, formatResult] = await Promise.all([
    supabase.from('categories').select('bar_id, id, name, icon, note, sort_order').eq('bar_id', bar.id).order('sort_order'),
    supabase.from('subcategories').select('bar_id, id, category_id, name, sort_order').eq('bar_id', bar.id).order('sort_order'),
    supabase.from('products').select('bar_id, id, subcategory_id, name, description, detailed_description, image_path, sort_order, active').eq('bar_id', bar.id).eq('active', true).order('sort_order'),
    supabase.from('product_formats').select('id, bar_id, product_id, name, price, sort_order').eq('bar_id', bar.id).order('sort_order'),
  ])

  if (categoryResult.error) throw categoryResult.error
  if (subcategoryResult.error) throw subcategoryResult.error
  if (productResult.error) throw productResult.error
  if (formatResult.error) throw formatResult.error

  const categories = (categoryResult.data ?? []) as CategoryRow[]
  const subcategories = (subcategoryResult.data ?? []) as SubcategoryRow[]
  const products = (productResult.data ?? []) as ProductRow[]
  const formats = (formatResult.data ?? []) as ProductFormatRow[]

  const categoryForSubcategory = new Map(subcategories.map((subcategory) => [subcategory.id, subcategory.category_id]))
  const categoriesWithSubcategories: MenuCategory[] = categories.map((category) => ({
    id: category.id,
    name: category.name,
    icon: category.icon,
    note: category.note || undefined,
    subcategories: subcategories
      .filter((subcategory) => subcategory.category_id === category.id)
      .map((subcategory) => ({ id: subcategory.id, name: subcategory.name })),
  }))

  const productsWithFormats: MenuProduct[] = products.map((product) => {
    const imagePath = product.image_path?.replace(/^\/+/, '')
    const image = imagePath
      ? supabase.storage.from('productos').getPublicUrl(imagePath).data.publicUrl
      : undefined

    return {
      id: product.id,
      name: product.name,
      description: product.description || undefined,
      detailedDescription: product.detailed_description || undefined,
      image,
      categoryId: categoryForSubcategory.get(product.subcategory_id) ?? '',
      subcategoryId: product.subcategory_id,
      formats: formats
        .filter((format) => format.product_id === product.id)
        .map((format) => ({ id: format.id, name: format.name, price: Number(format.price) })),
    }
  })

  const profile: BarProfile = {
    id: bar.id,
    name: bar.name,
    typeLabel: bar.type_label,
    introEyebrow: bar.intro_eyebrow,
    introNote: bar.intro_note || undefined,
    footerText: bar.footer_text || undefined,
    footerNote: bar.footer_note,
  }

  return { bar: profile, categories: categoriesWithSubcategories, products: productsWithFormats }
}

export async function resolveDiningTable(barId: string, publicCode: string) {
  const supabase = getSupabaseClient()
  const { data, error } = await supabase
    .from('bar_tables')
    .select('id, table_number')
    .eq('bar_id', barId)
    .eq('public_code', publicCode)
    .eq('active', true)
    .single()

  if (error) throw error
  return { id: data.id as string, label: String(data.table_number) }
}

export async function submitOrder(barSlug: string, tableCode: string, items: { formatId: string; quantity: number }[]) {
  const supabase = getSupabaseClient()
  const { data, error } = await supabase.rpc('create_table_order', {
    p_bar_slug: barSlug,
    p_table_code: tableCode,
    p_items: items,
  })

  if (error) throw error
  return data as { order_id: string; total: number }
}
