#encoding: utf-8

class Order < ActiveRecord::Base

  resourcify
  include Authority::Abilities
  include Adjustable

  #---
  # Store is the current store, store portal is an optional store id
  # for the portal store the originating hostname points to.
  belongs_to :store
  belongs_to :store_portal, class_name: 'Store'
  belongs_to :user

  belongs_to :order_type
  delegate :is_rfq?, :is_quote?, to: :order_type
  delegate :payment_gateway_class, to: :order_type

  default_scope { where(cancelled_at: nil) }

  scope :at, -> (store) { where(store: store) }

  # Current orders are completed, not yet approved orders.
  scope :current, -> { where.not(completed_at: nil).where(approved_at: nil) }

  # Pending orders are approved, not yet concluded orders.
  scope :pending, -> { where.not(approved_at: nil).where(concluded_at: nil) }

  # Complete orders, approved or not.
  scope :complete, -> { where.not(completed_at: nil) }

  # Incomplete orders is the scope for shopping carts.
  scope :incomplete, -> { where(completed_at: nil) }

  # Approved orders.
  scope :approved, -> { where.not(approved_at: nil) }

  # Concluded orders.
  scope :concluded, -> { where.not(concluded_at: nil) }

  # Cancelled orders.
  scope :cancelled, -> { unscope(where: :cancelled_at).where.not(cancelled_at: nil) }

  # Orders that are not concluded or have been concluded not longer than
  # one week ago are topical. This is used for timeline data.
  scope :topical, -> { where('concluded_at IS NULL OR concluded_at > ?', 2.weeks.ago) }

  #---
  validates :customer_name, presence: true, on: :update
  validates :customer_email, presence: true, on: :update
  validates :customer_phone, presence: true, on: :update

  #---
  # This attribute allows adding products en masse
  # through a string of comma-separated ids.
  attr_accessor :product_ids_string

  #---
  # Approve the order when approved_at first gets a value.
  after_save :approve!, if: -> (order) { order.approved_at_changed?(from: nil) }

  # Conclude the order when concluded_at first gets a value.
  after_save :conclude!, if: -> (order) { order.concluded_at_changed?(from: nil) }

  #---
  # Statuses that can be queried against.
  def self.statuses
    [:current, :pending, :concluded, :cancelled]
  end

  #---
  # Define methods to use archived copies of order attributes if the order
  # is concluded, otherwise go through the associations. See #archive! below.
  %w[store_name user_name user_email user_phone].each do |method|
    association, association_method = method.split('_', 2)
    define_method(method.to_sym) do
      concluded? ? self[method] : send(association).send(association_method)
    end
  end
  def order_type_name
    concluded? ? self[:order_type_name] : order_type.name
  end

  # Order source group is independent of order type.
  def source
    user.group(store)
  end

  # Order destination depends on the order type since there may be
  # multiple order types to choose from at checkout.
  delegate :destination, to: :order_type

  # Finds the order types applicable to this order in the context
  # of given group. These are the outgoing order types for the group,
  # excluding those that are not suitable for one or more products
  # present in the order items.
  def available_order_types(group)
    shipping_requirement = requires_shipping?
    return group.outgoing_order_types if shipping_requirement.nil?
    group.outgoing_order_types.where(has_shipping: requires_shipping?)
  end

  def editable_items?
    !complete?
  end

  def complete?
    completed_at.present?
  end

  def cancelled?
    cancelled_at.present?
  end

  def approved?
    !!approved_at.present?
  end

  def concluded?
    !!concluded_at.present?
  end

  # Order should complete when it reaches complete phase at checkout
  # but hasn't been completed yet.
  def should_complete?
    !complete? && checkout_phase == :complete
  end

  # Completing an order assigns it a number, archives it, sends
  # order receipt/acknowledge, and triggers an XML export job.
  def complete!
    assign_number!
    archive!
    email(has_payment? ? :receipt : :acknowledge, customer_string)
    export_xml
  end

  def assign_number!
    Order.with_advisory_lock('order_numbering') do
      current_max = store.orders.complete.maximum(:number).presence || store.order_sequence.presence || 0
      update(number: current_max.succ, completed_at: Time.current)
    end
  end

  # Archives the order and its items to permanently record data
  # that is subject to change.
  def archive!
    transaction do
      update(
        store_name: store.name,
        user_name: user.try(:name),
        user_email: user.try(:email),
        user_phone: user.try(:phone),
        order_type_name: order_type.name
      )
      order_items.each do |item|
        item.archive!
      end
    end
  end

  def has_installation?
    order_type.present? && order_type.has_installation?
  end

  # An order is quotable if it's a quote and there's a contact address.
  def quotable?
    is_quote? && contact_email.present?
  end

  def paid?
    balance <= 0.to_money
  end

  def balance
    grand_total_with_tax - payments.map(&:amount).sum
  end

  # Grand total for the given items (or whole order), without tax.
  def grand_total_sans_tax(items = order_items)
    items.map { |item| item.grand_total_sans_tax || 0.to_money }.sum + adjustments_sans_tax
  end

  # Same as above, with tax.
  def grand_total_with_tax(items = order_items)
    items.map { |item| item.grand_total_with_tax || 0.to_money }.sum + adjustments_with_tax
  end

  # Total tax for the given items.
  def tax_total(items = order_items)
    items.map { |item| item.tax_total || 0.to_money }.sum
  end

  def adjustments_sans_tax
    adjustments.map { |a| a.amount_sans_tax || 0.to_money }.sum
  end

  def adjustments_with_tax
    adjustments.map { |a| a.amount_with_tax || 0.to_money }.sum
  end

  # Grand total for exported orders.
  def grand_total_for_export(inventory, items = order_items)
    items.map { |item|
      (item.subtotal_for_export(inventory) || 0.to_money) + item.adjustments_sans_tax
    }.sum + adjustments_sans_tax
  end

  # Order phase in the checkout process. This is included in the JSON
  # representation for checkout.coffee to reveal the corresponding form
  # elements.
  def checkout_phase
    return :address  if !valid?
    return :shipping if has_shipping? && shipments.empty?
    return :payment  if has_payment? && !paid?
    return :complete
  end

  # Notify users with order_notify role in the destination group.
  def notified_users
    destination.users.with_role(:order_notify, store)
  end

  def email(message, to, items = nil, options = {})
    options.reverse_merge!(
      bcc: true,
      pricing: true
    )
    if store.disable_mail?
      logger.info "Sending of e-mail is currently disabled, aborting"
      return false
    else
      OrderMailer.send(message, self, to, items, options).deliver_later
    end
  end

  private
    # Perform XML export if specified by order type, and
    # store settings have a path defined.
    def export_xml
      if order_type.is_exported? && store.order_xml_path.present?
        OrderExportJob.perform_later(self, store.order_xml_path)
      end
    end

    # Approving an order sends the appropriate notifications.
    # If the order has already been paid, a processing notification
    # is sent. Otherwise an order confirmation is sent, and a copy
    # without pricing information is cc'd to the contact person.
    def approve!
      reload # to clear changes and prevent a callback loop
      if has_payment?
        email(:processing, customer_string, nil, bcc: false)
      else
        email(:confirmation, customer_string, nil, bcc: false)
        email(:confirmation, contact_string, nil, bcc: false, pricing: false) if has_contact_info?
      end
      items_by_vendor.each do |vendor, items|
        vendor.notified_users.each do |user|
          email(:notification, user.to_s, items, bcc: false, pricing: false)
        end
      end
      true
    end

    # Concluding an order creates asset entries for it.
    # A notification of shipment is sent.
    def conclude!
      reload # to clear changes and prevent a callback loop
      email(:shipment, customer_string, nil, bcc: false)
      email(:shipment, contact_string, nil, bcc: false, pricing: false) if has_contact_info?
      OrderReportRow.create_from(self)
      CustomerAsset.create_from(self)
      true
    end
end

require_dependency 'order/contents'
require_dependency 'order/shipping_and_billing'
require_dependency 'order/presentation'
