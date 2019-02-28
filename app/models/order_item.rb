class OrderItem < ApplicationRecord

  resourcify
  include Authority::Abilities
  include Adjustable
  include Reorderable
  monetize :price_cents, allow_nil: true

  #---
  belongs_to :order, inverse_of: :order_items, touch: true, counter_cache: true
  delegate :inventory, :includes_tax?, :track_shipments?, :approved?, :concluded?, to: :order

  has_many :transfer_items
  belongs_to :product
  delegate :live?, :real?, :internal?, :package?, :tangible?, :back_orderable?, to: :product

  # Order items may have subitems that update with their parent, and are not
  # directly updatable or removable.
  belongs_to :parent_item, class_name: 'OrderItem', optional: true
  has_many :subitems, class_name: 'OrderItem', foreign_key: :parent_item_id,
    dependent: :destroy

  default_scope { order(:priority) }
  scope :lot_codes_first, -> { reorder(lot_code: :desc) }
  scope :top_level, -> { where(parent_item_id: nil) }
  scope :live, -> { joins(:product).merge(Product.live) }
  scope :real, -> { joins(:product).merge(Product.real) }
  scope :tangible, -> { joins(:product).merge(Product.tangible) }
  scope :virtual, -> { joins(:product).merge(Product.virtual) }
  scope :pending, -> { joins(:product).merge(Product.tangible).where(
    arel_table[:shipped].eq(nil)
    .or(arel_table[:shipped].lt(arel_table[:amount])))
  }

  #---
  validates :amount, numericality: {integer_only: true, greater_than_or_equal_to: 1}, on: :update

  #---
  def is_subitem?
    parent_item.present?
  end

  def part_of_package?
    is_subitem? && parent_item.package?
  end

  # When an order item is updated, its subitems must be updated to reflect
  # the new amount according to the component entries of the product on
  # this order item.
  def reset_subitems!
    entries = product.component_entries
    subitems.each do |subitem|
      component = entries.find_by(component: subitem.product)
      subitem.update! amount: amount * component.quantity
    end
    reload
  end

  # Define methods to use archived copies of order items if the associated
  # order is concluded, otherwise go through the associations.
  %w[product_code product_customer_code product_title product_subtitle].each do |method|
    association, association_method = method.split('_', 2)
    define_method(method.to_sym) do
      concluded? ? self[method] : send(association).send(association_method)
    end
  end

  # Price without tax deducts the tax portion if it's included in the attribute.
  def price_sans_tax
    price_as_price.sans_tax
  end

  # Tax is calculated from the price attribute, which may include tax.
  def tax
    price_as_price.tax
  end

  # Price with tax adds the tax portion if it wasn't included.
  def price_with_tax
    price_as_price.with_tax
  end

  def subtotal_sans_tax
    return nil if price.nil?
    price_as_price.sans_tax * amount
  end

  def tax_subtotal
    return nil if price.nil?
    price_as_price.tax * amount
  end

  def subtotal_with_tax
    return nil if price.nil?
    price_as_price.with_tax * amount
  end

  # Prices and subtotals seen in cart context, where packages show
  # a single price for the parent item and no prices for subitems.
  def cart_price_sans_tax
    return nil if part_of_package?
    return price_with_subitems(:price_sans_tax) if package?
    price_sans_tax
  end

  def cart_price_with_tax
    return nil if part_of_package?
    return price_with_subitems(:price_with_tax) if package?
    price_with_tax
  end

  def cart_subtotal_sans_tax
    return nil if part_of_package?
    return price_with_subitems(:subtotal_sans_tax) if package?
    subtotal_sans_tax
  end

  def cart_subtotal_with_tax
    return nil if part_of_package?
    return price_with_subitems(:subtotal_with_tax) if package?
    subtotal_with_tax
  end

  def adjustments_sans_tax
    adjustments.map(&:amount_sans_tax).sum
  end

  def adjustments_tax
    adjustments.map(&:tax).sum
  end

  def adjustments_with_tax
    adjustments.map(&:amount_with_tax).sum
  end

  # Grand totals include adjustments.
  def grand_total_sans_tax
    (subtotal_sans_tax || 0.to_money) + adjustments_sans_tax
  end

  def tax_total
    (tax_subtotal || 0.to_money) + adjustments_tax
  end

  def grand_total_with_tax
    (subtotal_with_tax || 0.to_money) + adjustments_with_tax
  end

  # Price including subitems using given method on each.
  def price_with_subitems(method)
    send(method) + subitems.map { |i| i.send(method) }.sum
  end

  # Price for exported orders, always without tax.
  # Vendor products and items from prepaid stock are
  # listed without prices.
  def price_for_export
    return nil if product.vendor.present?
    return nil if use_prepaid_stock? && available?
    price_sans_tax
  end

  def subtotal_for_export
    return nil if product.vendor.present?
    return nil if use_prepaid_stock? && available?
    subtotal_sans_tax
  end

  def use_prepaid_stock?
    order.order_type.prepaid_stock?
  end

  # Stock calculations are offloaded to the product.
  def available
    @available ||= product.available(inventory, lot_code)
  end

  def available?
    @in_stock ||= product.available?(inventory, lot_code, amount)
  end

  def out_of_stock?
    !available?
  end

  def satisfied?
    product.satisfies?(inventory, lot_code, amount)
  end

  # Pending items have not been shipped. They may be loaded and
  # awaiting shipment though, see #waiting? and #waiting below.
  def pending?
    tangible? && pending > 0
  end

  def pending
    return 0 if !tangible?
    amount - (shipped || 0)
  end

  # Updates the shipped amount from completed transfer items.
  def update_shipped!
    update!(shipped: completed_transfer_items.sum(:amount))
  end

  # Transfer items in active shipments, shipped or not. See #loaded below.
  def active_transfer_items
    transfer_items.joins(transfer: :shipment).merge(Shipment.active)
  end

  def loaded
    active_transfer_items.sum(:amount)
  end

  def waiting?
    tangible? && waiting > 0
  end

  def waiting
    return 0 if !tangible?
    amount - loaded
  end

  # Date used in reports is the completion date of the order.
  def report_date
    order.completed_at.to_date
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

  def appearance
    return 'success' if available?
    return 'warning' if satisfied?
    'danger'
  end

  private
    # Transfer items in complete shipments, considered shipped.
    def completed_transfer_items
      transfer_items.joins(transfer: :shipment).merge(Shipment.complete)
    end

    # Price represented as a Price object for tax calculations.
    def price_as_price
      @price_as_price ||= Price.new(price, price_includes_tax?, tax_rate)
    end
end
