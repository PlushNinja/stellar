#encoding: utf-8

class Inventory < ActiveRecord::Base

  resourcify
  include Authority::Abilities
  include Reorderable

  #---
  belongs_to :store
  has_many :inventory_items, dependent: :destroy

  # Orders may specify a target inventory.
  has_many :orders

  default_scope { sorted }

  #---
  validates :name, presence: true

  #---
  # Finds an item by its lot code.
  def item_by_code(code)
    inventory_items.find_by(code: code)
  end

  def stock
    items = inventory_items
    [items, items.map(&:value).sum]
  end

  # Restocks the inventory with given transfer item that specifies
  # a product, a lot code, and an amount. New inventory items may
  # be created if not seen before.
  def restock!(transfer_item, timestamp, source = nil)
    item = inventory_items.find_or_initialize_by(
      product: transfer_item.product,
      code: transfer_item.lot_code
    )
    item.inventory_entries.build(
      recorded_at: timestamp,
      source: source,
      on_hand: transfer_item.amount,
      reserved: 0,
      pending: 0,
      value: item.value || transfer_item.product.cost_price || 0
    )
    item.save!
  end

  # Destocks the inventory from given transfer item that specifies
  # a product, a lot code, and an amount. The inventory item must exist.
  def destock!(transfer_item, timestamp, source = nil)
    item = inventory_items.find_by(
      product: transfer_item.product,
      code: transfer_item.lot_code
    )
    item.inventory_entries.build(
      recorded_at: timestamp,
      source: source,
      on_hand: -transfer_item.amount,
      reserved: 0,
      pending: 0,
      value: item.value
    )
    item.save!
  end

  def to_s
    name
  end
end
