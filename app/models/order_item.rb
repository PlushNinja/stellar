#encoding: utf-8

class OrderItem < ActiveRecord::Base

  monetize :price_cents, allow_nil: true
  #---

  belongs_to :order, inverse_of: :order_items
  belongs_to :product

  default_scope { order(:priority) }
  scope :real, -> { joins(:product).where(products: {virtual: false}) }

  #---
  delegate :virtual?, to: :product

  #---
  def subtotal
    amount * (price || 0)
  end

  def archive!
    update(
      product_code: product.code,
      product_customer_code: product.customer_code,
      product_title: product.title,
      product_subtitle: product.subtitle
    )
  end
end
