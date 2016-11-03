#encoding: utf-8

class CheckoutController < ApplicationController

  # This controller is aware of unauthenticated guests.
  def current_user
    super || guest_user
  end

  before_action :authenticate_user_or_skip!
  before_action :set_pages
  before_action :set_order
  before_action :set_pricing_group

  # POST /checkout/1/order_type/2.js
  # Setting an order type allows the user to proceed to checkout.
  # The order type tells us how to reappraise the order with user specific
  # pricing.
  def order_type
    @order.order_type = current_store.order_types.find(params[:order_type_id])
    @order.save!(validate: false)
    logger.info "Reappraising with pricing: #{current_pricing}"
    @order.reappraise!(current_pricing)
  end

  # GET /checkout/1
  # Entering checkout destroys any existing shipments to allow re-entry
  # to the checkout process.
  def checkout
    if @order.complete? || @order.empty? || !@order.checkoutable?
      return redirect_to cart_path
    end

    @shipping_methods = active_shipping_methods
    @order.shipments.destroy_all
    @order.address_to(current_user)

    if @order.has_payment?
      @payment_gateway = @order.payment_gateway_class.new(order: @order)
    end
  end

  # GET /checkout/1/shipping_method/2.js
  # Selecting a shipping method sets up a shipping gateway object that will
  # render its own interface within the view. Called via Ajax.
  def shipping_method
    @shipping_methods = active_shipping_methods
    @shipping_method = @shipping_methods.find(params[:method_id])
    @shipping_gateway = if @shipping_method.shipping_gateway.present?
      @shipping_method.shipping_gateway_class.new(order: @order)
    else
      nil
    end
  end

  # POST /checkout/1/ship/2.js
  # Shipping gateway views submit their form to this action via Ajax.
  # A shipment record is created, and the JS response will trigger an
  # order update.
  def ship
    @shipping_methods = active_shipping_methods
    @shipping_method = @shipping_methods.find(params[:method_id])
    @shipment = @order.shipments.build(
      shipping_method: @shipping_method,
      metadata: params[:metadata]
    )
    respond_to do |format|
      if @shipment.save
        format.js { render 'ship' }
      else
        head :bad_request
      end
    end
  end

  # GET /checkout/1/pay/credit_card.json
  def pay
    method = params[:method]

    if method.present? && @order.has_payment?
      @payment_gateway = @order.payment_gateway_class.new(order: @order, return_url: return_url(@order))
      response = @payment_gateway.send("charge_#{method}", params)
      render json: response
    else
      head :bad_request
    end
  end

  # POST /checkout/1/verify.json
  def verify
    token = params[:token]

    @payment_gateway = @order.payment_gateway_class.new(order: @order)
    status = @payment_gateway.verify(token)

    if status
      unless @order.paid?
        @order.payments.create(amount: @order.grand_total_with_tax)
      end
      head :ok
    else
      head :bad_request
    end
  end

  # GET /checkout/1/return
  def return
    @shipping_methods = active_shipping_methods
    @payment_gateway = @order.payment_gateway_class.new(order: @order)
    status = @payment_gateway.return(params)

    if status
      unless @order.paid?
        @order.payments.create(amount: @order.grand_total_with_tax)
      end
      render :success
    else
      redirect_to checkout_path(@order)
    end
  end

  # GET /checkout/1/receipt.js
  def receipt
  end

  private
    def set_order
      @order = current_user.orders.find(params[:order_id])
    end

    def active_shipping_methods
      if @order.has_shipping?
        current_store.shipping_methods.active
      else
        ShippingMethod.none
      end
    end
end
