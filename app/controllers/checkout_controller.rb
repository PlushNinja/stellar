#encoding: utf-8

class CheckoutController < ApplicationController

  # This controller is aware of unauthenticated guests.
  def current_user
    super || guest_user
  end

  def current_group
    delegate_group || super
  end

  before_action :authenticate_user_or_skip!
  before_action :set_header_and_footer
  before_action :set_categories, only: [:checkout, :return]
  before_action :set_order, except: [:notify]

  # POST /checkout/1/order_type/2.js
  # Setting an order type allows the user to proceed to checkout.
  def order_type
    @order.order_type = current_store.order_types.find(params[:order_type_id])
    @order.save!(validate: false)
  end

  # GET /checkout/1
  # Entering checkout destroys any existing shipments and shipping costs
  # to allow re-entry to the checkout process.
  def checkout
    if @order.complete? || @order.empty? || !@order.checkoutable?(current_inventory)
      return redirect_to cart_path
    end

    @shipping_methods = @order.available_shipping_methods
    @order.shipments.destroy_all
    @order.clear_shipping_costs!
    @order.address_to(current_user)

    if @order.has_payment?
      @payment_gateway = @order.payment_gateway_class.new(order: @order)
    end
  end

  # GET /checkout/1/shipping_method/2.js
  # Selecting a shipping method sets up a shipping gateway object that will
  # render its own interface within the view.
  # Called via Ajax.
  def shipping_method
    @shipping_methods = @order.available_shipping_methods
    @shipping_method = @shipping_methods.find(params[:method_id])
    @shipping_gateway = if @shipping_method.shipping_gateway.present?
      @shipping_method.shipping_gateway_class.new(order: @order)
    else
      nil
    end
  end

  # POST /checkout/1/ship/2.js
  # Shipping gateway views submit their form to this action via Ajax.
  # A shipment record is created, shipping cost added, and the JS response
  # will trigger an order update.
  def ship
    @shipping_methods = @order.available_shipping_methods
    @shipping_method = @shipping_methods.find(params[:method_id])
    @shipment = @order.shipments.build(
      shipping_method: @shipping_method,
      metadata: params[:metadata]
    )
    respond_to do |format|
      if @shipment.save
        @order.apply_shipping_cost!(@shipment, current_group)
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
      @payment_gateway = @order.payment_gateway_class.new(order: @order, return_url: return_url(@order), notify_url: notify_url(@order))
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
      @order.payments.create(amount: @order.grand_total_with_tax)
      head :ok
    else
      head :bad_request
    end
  end

  # GET /checkout/1/return
  def return
    @shipping_methods = @order.available_shipping_methods
    @payment_gateway = @order.payment_gateway_class.new(order: @order)
    number = @payment_gateway.return(params)

    if number
      @order.payments
        .find_or_create_by(number: number)
        .update(amount: @order.grand_total_with_tax)
      @order.complete! if @order.should_complete?
      render :success
    else
      redirect_to checkout_path(@order)
    end
  end

  # GET /checkout/1/notify
  # This action is reached without an active session when the payment
  # gateway performs a notify call after the user has failed to return
  # from the payment gateway. Therefore there is no current user and
  # no client to render any views to.
  def notify
    @order = Order.find(params[:order_id])
    @payment_gateway = @order.payment_gateway_class.new(order: @order)
    number = @payment_gateway.return(params)

    if number
      @order.payments
        .find_or_create_by(number: number)
        .update(amount: @order.grand_total_with_tax)
      @order.complete! if @order.should_complete?
      render nothing: true, status: :ok
    else
      render nothing: true, status: :unprocessable_entity
    end
  end

  # POST /checkout/1/confirm.js
  # This action is called when the customer wants to confirm her order
  # without having a payment collected. For security reasons the validity
  # of this operation is queried from the payment gateway.
  def confirm
    @payment_gateway = @order.payment_gateway_class.new(order: @order)
    if @payment_gateway.confirm
      @order.payments.create(amount: @order.grand_total_with_tax)
      head :ok
    else
      head :bad_request
    end
  end

  # GET /checkout/1/receipt.js
  def receipt
  end

  private
    def set_order
      @order = current_user.orders.find(params[:order_id])
    end
end
