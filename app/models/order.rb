#encoding: utf-8

class Order < ActiveRecord::Base

  resourcify
  include Authority::Abilities
  include Adjustable

  #---
  belongs_to :store
  belongs_to :user
  belongs_to :order_type
  delegate :is_rfq?, :is_quote?, to: :order_type

  has_many :order_items, dependent: :destroy, inverse_of: :order

  default_scope { order(created_at: :desc) }

  # Current orders are completed, not yet approved orders.
  scope :current, -> { where.not(completed_at: nil).where(approved_at: nil) }

  # Complete orders, approved or not.
  scope :complete, -> { where.not(completed_at: nil) }

  # Incomplete orders is the scope for shopping carts.
  scope :incomplete, -> { where(completed_at: nil) }

  # Approved orders.
  scope :approved, -> { where.not(approved_at: nil) }

  scope :managed_by, -> (user) { joins(:order_type).where(order_types: {id: user.managed_order_types}) }

  #---
  validates :customer_name, presence: true, on: :update
  validates :customer_email, presence: true, on: :update
  validates :customer_phone, presence: true, on: :update

  validates :shipping_address, :shipping_postalcode, :shipping_city,
    presence: true, on: :update,
    if: :has_shipping?

  validates :billing_address, :billing_postalcode, :billing_city,
    presence: true, on: :update,
    if: -> (order) { order.has_shipping? && order.has_billing_address? }

  #---
  before_save :copy_billing_address, unless: :has_billing_address?

  #---
  # Define methods to use archived copies of order attributes if the order
  # is approved, otherwise go through the associations. See #archive! below.
  %w[store_name user_name user_email].each do |method|
    association, association_method = method.split('_', 2)
    define_method(method.to_sym) do
      approved? ? self[method] : send(association).send(association_method)
    end
  end
  def order_type_name
    approved? ? self[:order_type_name] : order_type.name
  end

  # Only show prices for RFQs.
  def reveal_prices?
    is_rfq?
  end

  # Only show product components for non-RFQs.
  def reveal_components?
    !is_rfq?
  end

  # Users who may manage this order are order editors with the role defined
  # as the destination in the order type.
  def managing_users
    store.users.with_all_roles(:order_editor, order_type.destination_role.name)
  end

  def approval
    !!approved_at.present?
  end
  alias approved? approval

  # Setting approval status also archives the order and its order items.
  def approval=(status)
    case status
    when '1'
      archive!
      update(approved_at: Time.current)
    when '0'
      update(approved_at: nil)
    else
      raise "Unknown approval status #{status}"
    end
  end

  def insert!(product, amount)
    order_item = order_items.create_with(amount: 0).find_or_create_by(product: product)
    order_item.amount += amount
    order_item.price = product.sales_price
    order_item.save!
    apply_shipping_cost!
    apply_promotions!
  end

  # Applies a shipping cost for the current contents of the order.
  # The shipping cost is an order item referencing a virtual product
  # defined by the store.
  def apply_shipping_cost!
    return if store.shipping_cost_product.nil?
    item = order_items.create_with(
      amount: 1, priority: 1e9
    ).find_or_create_by(
      product: store.shipping_cost_product
    )
    item.update(price: calculated_shipping_cost)

    # Reloading order items that may have gone out of sync.
    order_items(reload)
  end

  # Applies active promotions on the order, first removing all existing
  # adjustments from the order and its items.
  def apply_promotions!
    adjustments.destroy_all
    order_items.each { |order_item| order_item.adjustments.destroy_all }

    store.promotions.active.each do |promotion|
      promotion.apply!(self)
    end
  end

  # Completing an order sets the completion timestamp and
  # assigns a number from the sequence in the store.
  def complete!
    Order.with_advisory_lock('order_numbering') do
      current_max = store.orders.complete.maximum(:number) || store.order_sequence
      update(number: current_max.succ, completed_at: Time.current)
    end
  end

  # Collects aggregated component quantities of all products in the order.
  # Returns a hash of quantities keyed by product object.
  def aggregated_components
    aggregated = {}.tap do |aggregated|
      order_items.each do |item|
        item.product.relationships.each do |relationship|
          aggregated[relationship.component] ||= 0
          aggregated[relationship.component] += item.amount * relationship.quantity
        end
      end
    end
  end

  # An order is empty when it's empty of non-virtual items.
  def empty?
    order_items.real.empty?
  end

  def has_shipping?
    order_type.present? && order_type.has_shipping?
  end

  def has_payment?
    order_type.present? && order_type.has_payment?
  end

  def payment_gateway
    order_type.present? && order_type.payment_gateway
  end

  def adjustment_total
    adjustments.map(&:amount).sum
  end

  # Total sum without virtual items (like shipping and handling).
  def total
    order_items.real.map { |item| item.subtotal + item.adjustment_total }.sum + adjustment_total
  end

  # Grand total, including virtual items.
  def grand_total
    order_items.map { |item| item.subtotal + item.adjustment_total }.sum + adjustment_total
  end

  def tab_name
    order_type.name
  end

  def summary
    [company_name, contact_person, shipping_city].compact.reject(&:empty?).join('/')
  end

  def to_s
    number
  end

  private
    def copy_billing_address
      self.billing_address = shipping_address
      self.billing_postalcode = shipping_postalcode
      self.billing_city = shipping_city
    end

    def calculated_shipping_cost
      default_price = store.shipping_cost_product.sales_price
      return default_price if store.free_shipping_at.nil? || total < store.free_shipping_at.to_money
      return 0.to_money
    end

    def archive!
      transaction do
        update(
          store_name: store.name,
          user_name: user.try(:name),
          user_email: user.try(:email),
          order_type_name: order_type.name
        )
        order_items.each do |item|
          item.archive!
        end
      end
    end
end
