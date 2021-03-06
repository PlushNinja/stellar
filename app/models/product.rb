class Product < ApplicationRecord

  resourcify
  include Authority::Abilities
  include Trackable
  include Documentable
  include Pictureable
  include Pageable
  include Reorderable
  include FriendlyId
  friendly_id :slugger, use: [:slugged, :scoped, :history], scope: :store

  enum purpose: {
    # Regular product
    vanilla: 0,
    # Bundles consist solely of their components
    bundle: 3,
    # Composites come with their components
    composite: 4,
    # Packages come with their components with a single price tag
    package: 2,
    # Virtual products are intangible, such as services
    virtual: 5,
    # Internal products are implied costs and other surcharges
    internal: 6,
    # Component products may not be purchased separately
    component: 7
  }

  # Additional sorting scopes through Reorderable.
  define_scope :alphabetical do
    order(:title, :subtitle)
  end
  define_scope :available_at_desc do
    order(available_at: :desc, created_at: :desc)
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

  # A product may belong to a specific vendor group who's responsible for it.
  belongs_to :vendor, class_name: 'Group', optional: true

  has_and_belongs_to_many :categories, after_add: :associations_changed, after_remove: :associations_changed

  has_and_belongs_to_many :tags, after_add: :associations_changed, after_remove: :associations_changed

  # If a product has associated shipping methods, only those shipping methods
  # are available when ordering this product.
  has_and_belongs_to_many :shipping_methods

  # Products may form master-variant relationships, and any change will
  # trigger a live status update.
  belongs_to :master_product, class_name: 'Product', inverse_of: :variants, touch: true, counter_cache: :variants_count, optional: true
  has_many :variants, class_name: 'Product', foreign_key: :master_product_id, inverse_of: :master_product, counter_cache: :variants_count, after_add: :associations_changed, after_remove: :associations_changed
  belongs_to :primary_variant, class_name: 'Product', optional: true

  # Products have a sales measure unit if it's sold in other that pcs.
  belongs_to :sales_measure_unit, class_name: 'MeasurementUnit', optional: true

  has_many :order_items

  # Product/component relationships in both directions. Component entries describe the connections between
  # a product and its component. First declare the straightforward relationship through component entries.
  has_many :component_entries, dependent: :destroy
  has_many :component_products, through: :component_entries, source: :component

  # Then use the component entries in reverse to connect a product to its component parents.
  has_many :component_parent_entries, class_name: 'ComponentEntry', foreign_key: :component_id
  has_many :component_parent_products, through: :component_parent_entries, source: :product

  has_many :requisite_entries, dependent: :destroy

  has_many :requisite_products, through: :requisite_entries, source: :requisite
  has_many :product_properties, dependent: :destroy, after_add: :associations_changed, after_remove: :associations_changed
  has_many :properties, through: :product_properties

  has_many :order_report_rows, dependent: :destroy

  scope :at, -> (store) { where(store: store) }

  # Real products are everything but internal costs.
  scope :real, -> { where.not(purpose: 6) }

  # Tangible products require shipping.
  scope :tangible, -> { where.not(purpose: [5, 6]) }

  scope :live, -> { where(live: true) }

  # Scopes for master and variant products based on associations present.
  scope :master, -> { where(master_product_id: nil) }
  scope :variant, -> { where.not(master_product_id: nil) }

  # Visible products are shown in storefront views. They include live
  # vanilla, bundle, composite, package, and virtual products, but not variants.
  scope :visible, -> {
    live.master.where(purpose: [0, 2, 3, 4, 5])
  }

  # Simple products exclude complex products: bundles, composites, and packages.
  scope :simple, -> {
    where.not(purpose: [2, 3, 4])
  }
  scope :complex, -> {
    where(purpose: [2, 3, 4])
  }

  scope :by_category_id, -> (ids) { joins(:categories).where(categories: {id: ids.map { |id| Category.self_and_descendant_ids(id) }.flatten}) }
  scope :not_including, -> (this) { where.not(id: this) }

  #---
  validates :code, presence: true, uniqueness: {scope: :store}
  validates :title, presence: true

  #---
  # This attribute allows adding requisite entries en masse
  # through a string of comma-separated ids.
  attr_accessor :requisite_ids_string

  #---
  before_save :reset_live_status
  before_save :inherit_from_master, if: :variant?
  after_save :update_variants, if: :has_variants?

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

  def self.described_options
    [
      [human_attribute_name(:described), true],
      [human_attribute_name(:not_described), false]
    ]
  end

  def self.illustrated_options
    [
      [human_attribute_name(:illustrated), true],
      [human_attribute_name(:not_illustrated), false]
    ]
  end

  # Finds the top 10 best selling products in the context of given order,
  # matching given order types, excepting items already present.
  def self.best_selling(order, order_types)
    if order_types.any?
      existing_ids = order.order_items.pluck(:product_id)
      search = OrderReportRowSearch.new(
        order_type: order_types,
        real_only: true,
        live: true,
        except_product_id: existing_ids,
        since_date: 1.month.ago.to_date,
        until_date: Date.current
      )
      top10 = Reports::Sales.new(search).best_selling
      Product.find(top10.map(&:product_id))
    else
      Product.none
    end
  end

  def self.available_uploaders
    %w{Csv Spreadsheetml Xml}
  end

  #---
  def real?
    !internal?
  end

  def tangible?
    !(virtual? || internal?)
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
    variants_count > 0
  end

  def has_component_parents?
    component_parent_entries.count > 0
  end

  def primary?
    variant? && master_product.primary_variant == self
  end

  def visible?
    live? && master? && (vanilla? || bundle? || composite? || package? || virtual?)
  end

  def purchasable?
    live? && !has_variants? && (vanilla? || bundle? || composite? || package? || virtual?)
  end

  # If additional info needs to be prompted, use an ordering modal.
  def modal_ordering?
    additional_info_prompt.present?
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
    pids = properties.pluck(:id)
    variants.live.sorted.includes(product_properties: :property)
      .map { |v|
        props = v.product_properties.map { |pp| [pp.property_id, pp] }.to_h
        [v, pids.map { |p| props[p] }]
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

  # Bundles, composites, and packages include components when ordered,
  # if any are live.
  def includes_components?
    (bundle? || composite? || package?) && component_entries.live.any?
  end

  # Finds the available shipping methods from associated active
  # shipping methods if any, defaulting to all active shipping methods.
  def available_shipping_methods
    shipping_methods.active.presence || store.shipping_methods.active
  end

  # Copies certain attributes from given master to create a valid variant.
  def vary_from(master)
    self.assign_attributes(
      purpose: master.purpose,
      master_product: master,
      categories: master.categories,
      tags: master.tags,
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
        alternate_prices: alternate_prices.map(&:dup),
        product_properties: product_properties.map(&:dup)
      )
      pictures.each do |picture|
        c.pictures << picture.duplicate
      end
    end
  end

  def generate_variant_code
    "#{code}-#{variants_count}"
  end

  def slugger
    [[:title], [:title, :subtitle], [:title, :subtitle, :code]]
  end

  def should_generate_new_friendly_id?
    (will_save_change_to_title? || will_save_change_to_subtitle? || will_save_change_to_code?) || super
  end

  def with_requisite_products
    [self] + requisite_products
  end

  protected

  # Resets the live status of the product, according to these criteria:
  # - set to be available at a certain date which is not in the future
  # - retail price is not nil (or product is a bundle or has variants)
  # - if set to be deleted at a certain date which is in the future
  def reset_live_status
    self.live =
        (available_at.present? && !available_at.future?) &&
        (retail_price_cents.present? || bundle? || has_variants?) &&
        (deleted_at.nil? || deleted_at.future?)
  end

  # Callback to touch the associated object that was added or removed,
  # and update the master/variants to bust their partial caches.
  def associations_changed(context)
    if persisted?
      context.touch if context.persisted?
      touch_master_and_variants if variant?
      update_variants if has_variants?
    end
  end

  # All variants are saved to have them inherit master categories and tags,
  # and touched to force a timestamp update in case no changes are made.
  def update_variants
    transaction do
      variants.each do |variant|
        variant.save
        variant.touch
      end
    end
  end

  # Complex component parents depend on this product to be live for them to be live as well.
  def update_component_parents
    return if live?
    transaction do
      component_parent_products.each do |parent|
        parent.update(deleted_at: Date.today)
      end
    end
  end

  # Variants don't have their own categories and tags,
  # instead they are inherited from their master product.
  def inherit_from_master
    self.categories = master_product.categories
    self.tags = master_product.tags
  end

  # Touches master and all its variants to bust partial caches.
  def touch_master_and_variants
    transaction do
      master_product.touch
      master_product.variants.each do |variant|
        variant.touch
      end
    end
  end

  # Adds an incrementing branch number to the product code.
  def reset_code
    while !valid?
      trunk, branch = code.partition(/ \(\d+\)/)
      branch = ' (0)' if branch.empty?
      self[:code] = "#{trunk}#{branch.succ}"
    end
  end
end

require_dependency 'product/pricing'
require_dependency 'product/inventory'
require_dependency 'product/presentation'
