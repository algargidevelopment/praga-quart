export interface MenuCategory {
  id: string
  name: string
  icon: string
  note?: string
  subcategories: MenuSubcategory[]
}

export interface MenuSubcategory {
  id: string
  name: string
}

export interface MenuProduct {
  id: string
  name: string
  description?: string
  detailedDescription?: string
  image?: string
  categoryId: string
  subcategoryId: string
  formats: {
    id: string
    name: string
    price: number
  }[]
}

export interface BarProfile {
  id: string
  name: string
  typeLabel: string
  introEyebrow: string
  introNote?: string
  footerText?: string
  footerNote: string
}

