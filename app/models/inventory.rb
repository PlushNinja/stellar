class Inventory < ApplicationRecord

  resourcify
  include Authority::Abilities
  include Trackable
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
  def self.available_gateways
    %w{Kaunotar}
  end

  #---
  # Finds an item by product and lot code.
  def item_by_product_and_code(product, code)
    items_by_product(product).find_by(code: code)
  end

  # Finds items by product.
  def items_by_product(product)
    inventory_items.for(product)
  end

  # Restocks the inventory with given item that specifies a product,
  # lot code, expiration, and amount. New inventory items may be
  # created if not seen before. The affected inventory item is returned.
  # Does nothing and returns nil if the product does not track stock.
  def restock!(item, timestamp, source = nil)
    return nil unless item.product.tracked_stock?

    inventory_item = inventory_items.create_with(
      expires_at: item.expires_at
    ).find_or_create_by!(
      product: item.product,
      code: item.lot_code
    )
    inventory_item.inventory_entries.create!(
      recorded_at: timestamp,
      source: source,
      on_hand: item.amount,
      reserved: 0,
      pending: 0,
      value: inventory_item.value || item.product.trade_price || 0
    )
    inventory_item
  end

  # Destocks the inventory using given item that specifies
  # a product, lot code, and amount. Returns the affected
  # inventory item. Does nothing and returns nil if
  # the product does not track stock.
  def destock!(item, timestamp, source = nil)
    return nil unless item.product.tracked_stock?

    inventory_item = inventory_items.find_by(
      product: item.product,
      code: item.lot_code
    )
    inventory_item.inventory_entries.create!(
      recorded_at: timestamp,
      source: source,
      on_hand: -item.amount,
      reserved: 0,
      pending: 0,
      value: inventory_item.value
    )
    inventory_item
  end

  def stock_query(product)
    Rails.cache.fetch("stock-#{self}-#{product}", expires_in: 5.minutes) do
      store.stock_gateway_singleton.stock(product)
    end
  end

  def to_s
    name
  end
end
