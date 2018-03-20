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

  attr_accessor :serial
  before_validation :override_lot_code_with_serial

  #---
  # The source inventory item associated with this tranfer item
  # is found by product and lot code from the source inventory.
  def source_item
    source.item_by_product_and_code(product, lot_code)
  end

  # Transfer items are feasible if there's enough stock.
  def feasible?
    return true if source.nil?
    inventory_item = source_item
    inventory_item.present? && inventory_item.available >= amount
  end

  def appearance
    complete? || feasible? || 'danger text-danger'
  end

  def customer_code=(val)
    self.product = Product.find_by(customer_code: val)
  end

  private
    def override_lot_code_with_serial
      self[:lot_code] = serial if serial.present?
    end
end
