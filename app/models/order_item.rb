#encoding: utf-8

class OrderItem < ActiveRecord::Base

  include Adjustable
  monetize :price_cents, allow_nil: true

  #---
  belongs_to :order, inverse_of: :order_items
  belongs_to :product

  default_scope { order(:priority) }
  scope :real, -> { joins(:product).where(products: {virtual: false}) }

  #---
  delegate :virtual?, to: :product
  delegate :approved?, to: :order

  #---
  # Reveal price and components when the order allows it.
  def reveal_price?
    order.reveal_prices?
  end
  def reveal_components?
    order.reveal_components? && product.relationships.any?
  end

  def subtotal
    amount * (price || 0)
  end

  def adjustment_total
    adjustments.map(&:amount).sum
  end

  def archive!
    update(
      product_code: product.code,
      product_customer_code: product.customer_code,
      product_title: product.title,
      product_subtitle: product.subtitle
    )
  end

  def to_s
    product.title
  end
end
