#encoding: utf-8

class Product < ActiveRecord::Base

  resourcify
  include Authority::Abilities
  include Imageable
  include Reorderable
  include FriendlyId
  friendly_id :slugger, use: [:slugged, :history]
  paginates_per 30

  enum purpose: {
    # Regular product
    vanilla: 0,
    # Bundles consist solely of their components
    bundle: 3,
    # Composites come with their components
    composite: 4,
    # Virtual products are intangible, such as services
    virtual: 5,
    # Internal products are implied costs and other surcharges
    internal: 6,
    # Component products may not be purchased separately
    component: 7
  }

  PURPOSE_ICONS = {
    'vanilla' => nil,
    'bundle' => 'archive',
    'composite' => 'object-group',
    'virtual' => 'magic',
    'internal' => 'link',
    'component' => 'puzzle-piece'
  }.freeze

  # Monetize product attributes.
  monetize :cost_price_cents, allow_nil: true
  monetize :trade_price_cents, allow_nil: true
  monetize :retail_price_cents, allow_nil: true
  monetize :promoted_price_cents, allow_nil: true

  # Monetize aggregate methods.
  monetize :price_cents, disable_validation: true
  monetize :price_tag_cents, disable_validation: true
  monetize :component_total_price_cents, disable_validation: true
  monetize :unit_price_cents, disable_validation: true

  INLINE_SEARCH_RESULTS = 20

  # Additional sorting scopes through Reorderable.
  define_scope :alphabetical do
    order(:title, :subtitle)
  end
  define_scope :retail_price_asc do
    order(retail_price_cents: :asc)
  end
  define_scope :retail_price_desc do
    order(retail_price_cents: :desc)
  end
  define_scope :random do
    reorder('RAND()')
  end

  #---
  belongs_to :store

  # A product may belong to a specific vendor user who's responsible for it.
  belongs_to :vendor, class_name: 'User'

  # Products must have a tax category
  belongs_to :tax_category, required: true

  # A product may belong to multiple categories, and must update its own
  # live status when the relationships change.
  has_and_belongs_to_many :categories, after_add: :reset_itself!, after_remove: :reset_itself!

  # If a product has associated shipping methods, only those shipping methods
  # are available when ordering this product.
  has_and_belongs_to_many :shipping_methods

  # Products may form master-variant relationships, and any change will
  # trigger a live status update.
  belongs_to :master_product, class_name: 'Product', inverse_of: :variants
  has_many :variants, class_name: 'Product', foreign_key: :master_product_id, inverse_of: :master_product, after_add: :reset_itself!, after_remove: :reset_itself!
  belongs_to :primary_variant, class_name: 'Product'

  has_many :inventory_items, dependent: :destroy
  has_many :order_items
  has_many :component_entries, dependent: :destroy
  has_many :component_products, through: :component_entries, source: :component
  has_many :requisite_entries, dependent: :destroy
  has_many :requisite_products, through: :requisite_entries, source: :requisite
  has_many :product_properties, dependent: :destroy
  has_many :properties, through: :product_properties

  # Products can be added to promotions, and any change will trigger
  # recalculation of its promoted price.
  has_many :promoted_items, after_add: :reset_itself!, after_remove: :reset_itself!
  has_many :promotions, through: :promoted_items

  has_many :iframes, dependent: :destroy

  # Alternate retail prices in pricing groups.
  has_many :alternate_prices, dependent: :destroy

  # Customer assets referring to this product.
  has_many :customer_assets

  has_one :page, as: :resource

  # Real products are everything but internal costs.
  scope :real, -> { where.not(purpose: purposes[:internal]) }

  scope :live, -> { where(live: true) }

  # Scopes for master and variant products based on associations present.
  scope :master, -> { where(master_product_id: nil) }
  scope :variant, -> { where.not(master_product_id: nil) }
  scope :having_variants, -> { joins(:variants).uniq }

  # Visible products are shown in storefront views. They include live
  # vanilla, bundle, composite, and virtual products, but not variants.
  scope :visible, -> {
    live.master.where(purpose: [0, 3, 4, 5])
  }

  scope :with_assets, -> { joins(:customer_assets).distinct }

  #---
  validates :code, presence: true, uniqueness: {scope: :store}
  validates :title, presence: true

  #---
  # This attribute allows adding requisite entries en masse
  # through a string of comma-separated ids.
  attr_accessor :requisite_ids_string

  #---
  after_save :touch_categories
  after_save :reset_live_status!

  #---
  def self.purpose_options
    purposes.keys.map { |p| [Product.human_attribute_value(:purpose, p), p] }
  end

  # Options for a search form.
  def self.availability_options
    [
      [human_attribute_name(:live), true],
      [human_attribute_name(:not_live), false]
    ]
  end

  # Takes a CSV::Row and updates a product from its data in the given store
  # and inventory. Returns the updated product, or nil if it fails.
  # Supported fields:
  # product_code     : required
  # retail_price     : anything supported by Monetize.parse
  # inventory_amount : targets the first inventory
  def self.update_from_csv_row(store, inventory, row, code)
    product = store.products.where(code: row[:product_code]).first
    return nil if product.nil? || inventory.nil?

    begin
      if row[:retail_price].present?
        product.update!(retail_price: row[:retail_price].to_money)
      end
      if row[:inventory_amount].present?
        product.inventory_items.destroy_all
        amount = row[:inventory_amount].to_i
        amount = 0 if amount < 0
        product.restock!(inventory, code, amount)
      end
      product
    rescue
      nil
    end
  end

  #---
  def real?
    !internal?
  end

  # Master products are merely those that are not variants,
  # regardless if they have any assigned variants.
  def master?
    !variant?
  end

  def variant?
    master_product.present?
  end

  def has_variants?
    variants.any?
  end

  def primary?
    variant? && master_product.primary_variant == self
  end

  def visible?
    live? && master? && (vanilla? || bundle? || composite? || virtual?)
  end

  def purchasable?
    live? && !has_variants? && (vanilla? || bundle? || composite? || virtual?) && available?
  end

  # Finds the primary or first live variant for this product.
  # Returns self if not a master product or there are no variants.
  def first_variant
    master? && primary_variant || variants.live.sorted.first || self
  end

  def sibling_variants
    master_product.variants.where.not(id: self)
  end

  def has_master_properties?
    variant? && master_product.properties.any?
  end

  def variants_with_master_properties
    return {} unless has_variants?
    variants.live.sorted.includes(product_properties: :property)
      .map { |v|
        [v, v.product_properties.where(properties: {id: properties})]
      }
  end

  # Finds product properties that differ from the baseline established
  # by given product. Properties unique to this product are retained.
  def distinct_properties(product)
    baseline = product.product_properties_hash
    product_properties.select { |product_property|
      baseline[product_property.property_id] != product_property.value
    }
  end

  # Finds the set of unique properties across all variants of a master product.
  # Returns a hash keyed by property, or an empty set if there are no variants.
  def unique_properties
    return [] unless has_variants?
    variants.map(&:product_properties).flatten.group_by(&:property).select { |p, v| v.uniq(&:value).count > 1 }
  end

  # If a single category is requested, give the deepest live one.
  def category
    categories.live.order(depth: :desc, lft: :asc).first
  end

  def searchable_product_properties
    product_properties.joins(:property).merge(Property.searchable).merge(Property.sorted)
  end

  # Assigned product properties as a hash keyed by property id.
  # Useful for comparison, see #distinct_properties.
  def product_properties_hash
    product_properties.pluck(:property_id, :value).to_h
  end

  def active_promoted_items
    promoted_items.joins(:promotion).merge(Promotion.active)
  end

  # Finds the promoted item with the lowest quoted price.
  def best_promoted_item
    lowest = active_promoted_items.pluck(:price_cents).compact.min
    return nil if lowest.nil?
    active_promoted_items.find_by(price_cents: lowest)
  end

  # Returns the retail price in given pricing group. If no group is specified,
  # uses the promoted price, if any. Bundles sum their components if no price
  # is specified.
  def price_cents(pricing_group)
    if bundle? && retail_price_cents.nil?
      return component_total_price_cents(pricing_group)
    end
    if pricing_group.present?
      return alternate_prices.find_by(pricing_group: pricing_group).try(:retail_price_cents) || retail_price_cents
    end
    promoted_price_cents || retail_price_cents
  end

  # Returns the display price in given pricing group. The price tag displays
  # retail price, with components added on for composite products.
  def price_tag_cents(pricing_group)
    return price_cents(pricing_group) unless composite?
    price_cents(pricing_group) + component_total_price_cents(pricing_group)
  end

  # Total price of components.
  def component_total_price_cents(pricing_group)
    component_entries.map { |entry| entry.quantity * (entry.component.price_cents(pricing_group) || 0) }.sum
  end

  # Calculates unit price from given total cents by finding a product
  # property that declares unit pricing.
  def unit_price_cents(total_cents)
    return nil if total_cents.nil?
    product_property = unit_pricing_property
    return nil if product_property.nil? || product_property.value.nil?
    measure = product_property.value.tr(',', '.').to_f
    return nil if measure == 0
    total_cents / (measure * product_property.property.measurement_unit.factor)
  end

  # Returns the unit (if any) that unit pricing is based on.
  def base_unit
    product_property = unit_pricing_property
    return nil if product_property.nil?
    product_property.property.measurement_unit.pricing_base
  end

  # Returns the range of price tags across variants of a master product.
  def price_range(pricing_group)
    return nil unless has_variants?
    variants.map { |variant| variant.price_tag(pricing_group) }.compact.minmax
  end

  # Markup percentage from trade price to retail price.
  def markup_percent
    return nil if trade_price.nil? || retail_price.nil? || trade_price == 0
    100 * (retail_price - trade_price) / trade_price
  end

  # Margin percentage from trade price to retail price.
  def margin_percent
    return nil if trade_price.nil? || retail_price.nil? || retail_price == 0
    100 * (retail_price - trade_price) / retail_price
  end

  # Bundles and composites include components when ordered, if any are live.
  def includes_components?
    (bundle? || composite?) && component_entries.live.any?
  end

  # Stock is not tracked for bundles, virtual or internal products.
  def tracked_stock?
    vanilla? || composite?
  end

  # Amount available in all inventories.
  def available
    if tracked_stock?
      inventory_items.online.map(&:available).sum
    else
      Float::INFINITY
    end
  end

  # Product is considered available when it's live and has either inventory
  # available, or a defined lead time.
  def available?
    live? && (lead_time.present? || available > 0)
  end

  # Lead times that look like integers are parsed as number of days,
  # other non-blank strings are considered to be zero days.
  def lead_time_days
    lead_time.present? && lead_time.to_i
  end

  # Finds the available shipping methods from associated active
  # shipping methods if any, defaulting to all active shipping methods.
  def available_shipping_methods
    shipping_methods.active.presence || store.shipping_methods.active
  end

  # Coalesced amount available by inventory.
  def available_by_inventory
    amounts = inventory_items.online.group(:inventory_id).sum('on_hand - reserved')
    amounts.transform_keys { |id| Inventory.find(id) }
  end

  # Restocks given inventory with amount of this product with given lot code,
  # at given value. If value is not specified, uses the current value of the
  # targeted inventory item, defaulting to product cost price.
  def restock!(inventory, code, amount, value = nil, recorded_at = nil)
    recorded_at ||= Date.today
    item = inventory_items.find_or_initialize_by(
      inventory: inventory,
      code: code
    )
    item.inventory_entries.build(
      recorded_at: recorded_at,
      on_hand: amount,
      reserved: 0,
      pending: 0,
      value: value || item.value || cost_price || 0
    )
    item.save!
  end

  # Consumes given amount of this product from inventory, starting from
  # the oldest stock. Multiple inventory items may be affected to satisfy
  # the consumed amount. Returns false if we have insufficient stock available.
  def consume!(amount, source = nil)
    return true if !tracked_stock?
    return false if amount > available
    inventory_items.online.each do |item|
      if item.available >= amount
        # This inventory item satisfies the amount, destock and finish.
        item.destock!(amount, source)
        break
      else
        # Continue with remaining amount after destocking all of this item.
        amount -= item.available
        item.destock!(item.available, source)
      end
    end
  end

  def available_variant_options
    store.products.variant.map { |p| [p.to_s, p.id] }
  end

  # Copies certain attributes from given master to create a valid variant.
  def vary_from(master)
    self.assign_attributes(
      purpose: master.purpose,
      master_product: master,
      categories: master.categories,
      code: master.generate_variant_code,
      title: master.title,
      subtitle: master.subtitle,
      cost_price_cents: master.cost_price_cents,
      trade_price_cents: master.trade_price_cents,
      retail_price_cents: master.retail_price_cents,
      tax_category: master.tax_category,
    )
  end

  # Creates a duplicate of this product, including associations.
  # Any variants the product may have are not duplicated.
  def duplicate!
    clone = dup.tap do |c|
      c.reset_code
      c.save
      c.update(
        categories: categories,
        component_products: component_products,
        requisite_products: requisite_products,
        iframes: iframes.map(&:dup),
        alternate_prices: alternate_prices.map(&:dup),
        product_properties: product_properties.map(&:dup)
      )
      images.each do |image|
        c.images.create(
          priority: image.priority,
          purpose: image.purpose,
          attachment: image.attachment
        )
      end
    end
  end

  def generate_variant_code
    "#{code}-#{variants.count}"
  end

  def slugger
    [[:title, :subtitle, :code], [:title, :subtitle, :code, -> { store.name }]]
  end

  def should_generate_new_friendly_id?
    (title_changed? || subtitle_changed? || code_changed?) || super
  end

  def with_requisite_products
    [self] + requisite_products
  end

  # Limelighting a product in portal views needs both images and text.
  def limelightable?
    cover_image.present? && description.present?
  end

  # Icon name based on purpose.
  def icon
    PURPOSE_ICONS[purpose]
  end

  def codes
    customer_code.present? ? "#{customer_code} ⧸ #{code}" : code
  end

  def to_s
    "#{title} #{subtitle}"
  end

  def as_json(options = {})
    super({
      only: [:id, :code, :customer_code, :title, :subtitle],
      methods: [:icon_image_url]
    }.merge(options))
  end

  def icon_image_url
    cover_image.present? && cover_image(:presentational).url(:icon)
  end

  # Retail price string representation for JSON.
  def formatted_price_string
    retail_price.present? ? retail_price.format : ''
  end

  # Resets the live status of the product, according to these criteria:
  # - retail price is not nil (or there are variants)
  # - set to be available at a certain date which is not in the future
  # - if set to be deleted at a certain date which is in the future
  def reset_live_status!
    update_columns(live: (retail_price_cents.present? || has_variants?) &&
      (available_at.present? && !available_at.future?) &&
      (deleted_at.nil? || deleted_at.future?))
    touch
    true
  end

  # Resets the promoted price of the product by looking for the lowest price
  # from currently active promotions. Resets to nil if no promotions are found.
  def reset_promoted_price!
    lowest = best_promoted_item
    update_columns(promoted_price_cents: lowest.present? ? lowest.price_cents : nil)
    touch
    true
  end

  protected
    def reset_itself!(context)
      if persisted?
        reset_live_status!
        reset_promoted_price!
      end
    end

    def touch_categories
      categories.each(&:touch)
    end

    # Adds an incrementing branch number to the product code.
    def reset_code
      while !valid?
        trunk, branch = code.partition(/ \(\d+\)/)
        branch = ' (0)' if branch.empty?
        self[:code] = "#{trunk}#{branch.succ}"
      end
    end

  private
    def unit_pricing_property
      product_properties.joins(:property).merge(Property.unit_pricing).first
    end
end
