#encoding: utf-8
#
# OrderReportRows aggregate data from concluded orders to facilitate
# report generation. They are created or updated automatically when
# orders are concluded, or can be recreated via a rake task.
#
class OrderReportRow < ActiveRecord::Base

  monetize :total_sans_tax_cents, disable_validation: true
  monetize :total_with_tax_cents, disable_validation: true
  monetize :total_tax_cents, disable_validation: true

  #---
  belongs_to :order_type
  belongs_to :user
  belongs_to :store_portal, class_name: 'Store'
  belongs_to :shipping_country, class_name: 'Country', foreign_key: :shipping_country_code
  belongs_to :product

  #---
  # Creates or updates a report row from given order and its item.
  # Rows are aggregated by order type, shipping country, and product
  # to collect as many order items to a single slot as possible.
  # Orders made by non-guest users are further distinguished by user.
  def self.create_from_order_and_item(order, order_item)
    product = order_item.product
    return false unless product.present?
    row = where(
      order_type: order.order_type,
      user: order.user.guest?(order.store) ? nil : order.user,
      store_portal: order.store_portal,
      shipping_country_code: order.shipping_country_code,
      product: product,
      ordered_at: order.completed_at.to_date,
      tax_rate: order_item.tax_rate
    ).first_or_initialize { |row| row.total_value_cents = 0 }
    row.amount += order_item.amount
    row.total_sans_tax_cents += order_item.grand_total_sans_tax.cents
    row.total_with_tax_cents += order_item.grand_total_with_tax.cents
    row.total_tax_cents += order_item.tax_total.cents
    row.save
  end

  def self.create_from(order)
    transaction do
      order.order_items.each do |item|
        create_from_order_and_item(order, item)
      end
    end
  end
end
