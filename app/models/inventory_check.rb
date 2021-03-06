class InventoryCheck < ApplicationRecord

  resourcify
  include Authority::Abilities
  include Trackable

  #---
  belongs_to :store
  belongs_to :inventory

  # This association has an extension to merge a new inventory check item
  # with an existing similar item, because the item needs to be built first
  # to include a product id needed for find_or_initialize_by
  has_many :inventory_check_items, dependent: :destroy do
    def merge(new_item)
      find_or_initialize_by(
        product: new_item.product,
        lot_code: new_item.lot_code
      ).tap do |item|
        item.current += new_item.current
      end
    end
  end

  default_scope { order(created_at: :desc) }

  scope :complete, -> { where.not(completed_at: nil) }

  #---
  # This attribute allows seeding the inventory check with
  # entries matching products by category.
  attr_accessor :category_ids
  after_create :seed_from_category_ids

  #---
  def complete?
    completed_at.present?
  end

  def incomplete?
    !complete?
  end

  def complete!
    update completed_at: Time.current
  end

  def conclude!
    update concluded_at: Time.current
  end

  def concluded?
    concluded_at.present?
  end

  def invoice_params
    {
      inventory_id: inventory,
      payload_gid: to_global_id
    }
  end

  # Converts inventory check items to a list of argument hashes that can be given to Order#insert.
  def payload_contents
    inventory_check_items.for_payload.map(&:as_payload)
  end

  def to_csv
    attributes = %w{product_code product_title product_subtitle lot_code expires_at was_on_hand current difference}
    CSV.generate(
      headers: true,
      col_sep: ';'
    ) do |csv|
      csv << attributes
      inventory_check_items.each do |item|
        csv << attributes.map { |k| item.send(k) }
      end
    end
  end

  def appearance
    return nil if concluded?
    complete? ? 'info text-info' : 'warning text-warning'
  end

  def label
    "%s %s" % [self.class.model_name.human, id]
  end

  def life_pro_tip
    return [:info, '.concluded'] if concluded?
    return [:warning, '.complete'] if complete?
    [:danger, '.incomplete']
  end

  def icon
    return nil if concluded?
    complete? ? 'refresh' : 'cog'
  end

  def to_s
    note
  end

  private

  def seed_from_category_ids
    selected_ids = category_ids.reject(&:blank?)
    categories = selected_ids.any? ? selected_ids : store.categories.pluck(:id)
    search = InventoryItemSearch.new(inventory_id: inventory, categories: categories)
    inventory_items = search.results.reorder('products.title DESC, products.subtitle DESC')
    transaction do
      inventory_items.each do |inventory_item|
        inventory_check_items.create(
          inventory_item: inventory_item,
          product: inventory_item.product,
          lot_code: inventory_item.code,
          expires_at: inventory_item.expires_at
        )
      end
    end
  end
end
