#encoding: utf-8
#
# Transfer items record what is transferred by product and lot code.
#
class TransferItem < ActiveRecord::Base

  resourcify
  include Authority::Abilities

  #---
  belongs_to :transfer
  delegate :complete?, :source, :destination, to: :transfer

  # Transfer items may reference an order item they were created for.
  belongs_to :order_item

  belongs_to :product

  #---
  validates :product_id, presence: true
  validates :lot_code, presence: true
  validates :amount, numericality: {
    integer_only: true,
    greater_than_or_equal_to: 1
  }

  #---
  # The source inventory item associated with this tranfer item
  # is found by product and lot code from the source inventory.
  def source_item
    source.inventory_items.find_by(
      product: product,
      code: lot_code
    )
  end

  # Transfer items are feasible if there's enough stock.
  def feasible?
    source_item.present? && source_item.available >= amount
  end

  def appearance
    complete? || feasible? || 'danger text-danger'
  end
end
