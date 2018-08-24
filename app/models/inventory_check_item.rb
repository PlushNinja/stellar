#encoding: utf-8

class InventoryCheckItem < ActiveRecord::Base

  resourcify
  include Authority::Abilities

  #---
  belongs_to :inventory_check
  belongs_to :product

  # Inventory check items have a product association and
  # attributes for lot code, expiration, and on hand amount,
  # but may be associated with a matching inventory item.
  belongs_to :inventory_item

  #---
  validates :inventory_check_id, presence: true
  validates :product_id, presence: true
  validates :code, presence: true
end
