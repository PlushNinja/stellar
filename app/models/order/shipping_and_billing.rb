class Order < ActiveRecord::Base

  has_many :payments, dependent: :destroy, inverse_of: :order
  has_many :shipments, dependent: :destroy, inverse_of: :order

  # Shipping and billing addresses have country associations.
  belongs_to :shipping_country, class_name: 'Country', foreign_key: :shipping_country_code
  belongs_to :billing_country, class_name: 'Country', foreign_key: :billing_country_code

  validates :shipping_address, :shipping_postalcode, :shipping_city, :shipping_country_code, presence: true, on: :update,
    if: :has_shipping?

  validates :billing_address, :billing_postalcode, :billing_city, :billing_country_code, presence: true, on: :update,
    if: :billing_address_required?

  before_validation :copy_billing_address, if: :should_copy_billing_address?
  before_validation :ensure_valid_countries, on: :update

  def should_copy_billing_address?
    has_shipping? && has_payment? && !has_billing_address?
  end

  def billing_address_required?
    has_billing_address? || has_payment? && !has_shipping?
  end

  # Order having shipping is simply from the order type,
  # once it has been assigned. See #requires_shipping?
  def has_shipping?
    order_type.present? && order_type.has_shipping?
  end
  scope :has_shipping, -> { joins(:order_type).merge(OrderType.has_shipping) }

  def earliest_shipping_at(inventory)
    (completed_at || Date.current).to_date + lead_time_days(inventory).days
  end

  # Finds the shipping methods available for this order based on which
  # methods are common to all ordered items. In case the order needs no
  # shipping, no shipping methods are returned.
  def available_shipping_methods
    return ShippingMethod.none unless has_shipping?
    ids = order_items.map { |item| item.product.available_shipping_methods.pluck(:id) }.inject(:&)
    store.shipping_methods.where(id: ids)
  end

  def has_payment?
    order_type.present? && order_type.has_payment?
  end

  def billing_address_components
    has_billing_address? ?
      [billing_address, billing_postalcode, billing_city] :
      [shipping_address, shipping_postalcode, shipping_city]
  end

  # VAT numbers are not mandatory, but expected to be present in orders
  # billed at a different country from the store home country.
  def vat_number_expected?
    return false unless has_payment?
    if has_billing_address?
      billing_country != store.country
    else
      shipping_country != store.country
    end
  end

  # Addresses this order to the given user if she has any addresses defined.
  def address_to(user)
    if user.shipping_address.present?
      self.shipping_address = user.shipping_address
      self.shipping_postalcode = user.shipping_postalcode
      self.shipping_city = user.shipping_city
      self.shipping_country = user.shipping_country
    end
    if user.billing_address.present?
      self.has_billing_address = true
      self.billing_address = user.billing_address
      self.billing_postalcode = user.billing_postalcode
      self.billing_city = user.billing_city
      self.billing_country = user.billing_country
    end
    ensure_valid_countries
  end

  # Inserts an order item for the shipping cost using the shipping cost
  # product with the price queried from the given shipment.
  def apply_shipping_cost!(shipment, group)
    pricing = Appraiser::Product.new(group || source)
    cost = shipment.cost(pricing)
    unless cost.nil?
      order_items.create(
        product: shipment.shipping_cost_product,
        amount: 1,
        priority: 1e9,
        price: cost.amount,
        tax_rate: cost.tax_rate,
        price_includes_tax: cost.tax_included,
        label: ''
      )
    end
    order_items.reload
  end

  def clear_shipping_costs!
    order_items.where(product: store.shipping_cost_products).destroy_all
    order_items.reload
  end

  private
    def copy_billing_address
      self.billing_address = shipping_address
      self.billing_postalcode = shipping_postalcode
      self.billing_city = shipping_city
      self.billing_country = shipping_country
      true
    end

    def ensure_valid_countries
      self.shipping_country = store.country if shipping_country.nil?
      self.billing_country = store.country if billing_country.nil?
      true
    end
end
