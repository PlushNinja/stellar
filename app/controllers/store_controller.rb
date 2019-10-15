class StoreController < BaseStoreController

  # This controller is aware of unauthenticated guests.
  def current_user
    super || guest_user
  end

  # Unauthenticated guests may visit the store.
  before_action :authenticate_user_or_skip!, except: [:index, :show_page, :lookup]

  with_options only: [:front, :cart, :show_category, :show_category_order, :show_department, :show_page, :show_product, :show_promotion, :show_tag, :show_product_filter] do
    before_action :set_categories
    before_action :set_departments
  end

  authority_actions show_page: 'read'

  # GET /
  def index
    if current_store.present?
      entry_point = store_header.descendants.visible(current_group).entry_point
      return redirect_to entry_point.present? ? show_page_path(entry_point) : front_path
    end
    render :index, layout: 'devise'
  end

  # GET /front
  def front
    @category = @live_categories.first
    if @category.present?
      return redirect_to show_category_path(@category)
    end
  end

  # GET /cart
  def cart
    @order = shopping_cart
    @order.refresh!
    @order_types = @order.available_order_types

    respond_to do |format|
      format.html { render current_store.fancy_cart? ? :fancy_cart : :cart }
      format.json
    end
  end

  # GET /category/:category_id
  def show_category
    find_category
    apply_redirecting && return
    @view_mode = get_view_mode_setting(@category)
    @search = prepare_category_search

    respond_to do |format|
      format.js {
        results = @search.results.visible.sorted(@category.product_scope)
        @products = results.page(params[:page])
      }
      format.html
    end
  end

  # GET /category/:category_id/order
  def show_category_order
    find_category
    apply_redirecting && return
    @search = prepare_category_search

    respond_to do |format|
      format.js {
        results = @search.results.visible.sorted(@category.product_scope)
        @products = results.simple.page(params[:page])
      }
      format.html
    end
  end

  # GET /department/:department_id
  def show_department
    find_department
    @products = @department.products.live.random.page(params[:page]).per(24)

    respond_to :js, :html
  end

  # GET /product/:product_id(/:category_id)
  def show_product
    find_first_variant_product
    @category ||= if params[:category_id].present?
      @live_categories.friendly.find(params[:category_id])
    else
      @product.category
    end

    respond_to :js, :html
  end

  # GET /promotion/:promotion_id
  def show_promotion
    @promotion = current_store.promotions
      .active.friendly.find(params[:promotion_id])

    respond_to do |format|
      format.js {
        @products = @promotion.products.visible.page(params[:page])
      }
      format.html
    end
  end

  # GET /tag/:tag_id
  def show_tag
    @tag = current_store.tags.friendly.find(params[:tag_id])

    respond_to do |format|
      format.js {
        @products = @tag.products.live.page(params[:page])
      }
      format.html
    end
  end

  # GET /:slug
  # Multiplexer to call different actions depending on page type.
  def show_page
    @page = current_store.pages.friendly.find(params[:slug])
    authorize_action_for @page, at: current_store, for: current_group

    case @page.purpose.to_sym
    when :primary, :continuous, :route, :proxy, :stationary
      render :show_page
    when :category
      show_category_as_page
    when :category_order
      show_category_order_as_page
    when :department
      show_department_as_page
    when :product
      show_product_as_page
    when :promotion
      show_promotion_as_page
    when :internal
      @page = @page.resource
      render :show_page
    else
      raise 'Unknown page type'
    end
  end

  # Same as #show_category but in the context of a page.
  def show_category_as_page
    @category = @page.resource
    apply_redirecting && return
    @view_mode = get_view_mode_setting(@category)
    @search = prepare_category_search

    render :show_category_as_page
  end

  def show_category_order_as_page
    @category = @page.resource
    @search = prepare_category_search

    render :show_category_order_as_page
  end

  def show_department_as_page
    @department = @page.resource
    @products = @department.products.live.random.page(params[:page]).per(24)

    respond_to do |format|
      format.any(:js, :html) { render :show_department_as_page }
    end
  end

  def show_promotion_as_page
    @promotion = @page.resource

    render :show_promotion_as_page
  end

  def show_product_as_page
    @product = @page.resource.first_variant
    @category = @product.category

    render :show_product_as_page
  end

  # GET /store/lookup.js
  def lookup
    query = params.permit(:keyword)
    category_search = CategorySearch.new(query.merge(category_lookup_params))
    product_search = ProductSearch.new(query.merge(product_lookup_params))
    page_search = PageSearch.new(query.merge(page_lookup_params))
    @category_results = category_search.results
    @product_results = product_search.results.visible
      .limit(Product::INLINE_SEARCH_RESULTS)
    @page_results = page_search.results
    @results = @category_results.any? || @product_results.any? || @page_results.any?

    respond_to :js
  end

  # GET /products/filter.js
  def show_product_filter
    find_category
    @products_url = params[:products_url]
    @search = prepare_category_search

    respond_to :js
  end

  # GET /products/promoted/1.js
  def show_promoted_products
    order_types = selected_group.outgoing_order_types
    @products = Product.best_selling(shopping_cart, order_types)

    respond_to :js
  end

  # POST /cart/activate_code.js
  def activate_code
    activation_code = params[:activation_code]
    @order = shopping_cart
    @order_types = @order.available_order_types
    @promotion = current_store.promotions.live.locked.find_by(
      activation_code: activation_code
    )
    if @promotion.present? && @order.activated_promotions.exclude?(@promotion)
      @order.activated_promotions << @promotion
      @order.recalculate!
      flash.now[:notice] = t('.notice', promotion: @promotion)
    end

    respond_to :js
  end

  # GET /cart/quote/:recipient.js
  def quote
    @order = shopping_cart
    @recipient = case params[:recipient]
    when 'self'
      current_user
    when 'customer'
      @order.customer
    else
      return head :bad_request
    end
    @order.email.quotation(to: @recipient.to_s)

    flash.now[:notice] = t('.notice', email: @recipient.email)
    respond_to :js
  end

  # GET /cart/delete
  def delete_cart
    @order = shopping_cart
    @order.destroy

    redirect_to cart_path, notice: t('.notice')
  end

  # GET /product/:product_id/stock/:inventory_id.json
  # GET /product/:product_id/stock/:inventory_id.js
  def show_product_stock
    find_product
    @inventory = current_store.inventories.find_by(id: params[:inventory_id])
    @available = @product.available(@inventory, nil)

    respond_to do |format|
      format.json { render json: {available: @available, backOrder: @product.back_orderable?}}
      format.js {
        @update = params[:update]
      }
    end
  end

  # POST /product/:product_id/order.js
  def order_product
    @order = shopping_cart
    @order_types = @order.available_order_types
    find_product
    amount = params[:amount].to_i
    options = {}
    options[:additional_info] = params[:additional_info] if params[:additional_info].present?
    @order.insert(@product, amount, @order.billing_group, options)
    @order.recalculate!

    flash.now[:notice] = t('.notice', product: @product, amount: amount)
    respond_to :js
  end

  # GET /product/:product_id/set_order_amount.js
  def set_order_amount
    @order = shopping_cart
    find_product
    amount = params[:amount].to_i
    @order.set_amount(@product, amount, @order.billing_group)
    @order.recalculate!

    respond_to :js
  end

  # GET /store/favorites.js
  # GET /store/favorites.json
  def show_favorites
    @products = current_user.favorite_products.at(current_store)
    respond_to :js, :json
  end

  # GET /store/favorites/:product_id
  def show_favorite
    find_product
    redirect_to show_product_path(@product)
  end

  # POST /store/favorites/:product_id.js
  def add_favorite
    find_product
    favorites = current_user.favorite_products
    favorites << @product unless favorites.include?(@product)
    respond_to :js
  end

  # DELETE /store/favorites/:product_id.js
  def remove_favorite
    find_product
    current_user.favorite_products.delete(@product)
    respond_to :js
  end

  private
    # Find category from live categories by friendly id, including history.
    def find_category
      @category = @live_categories.friendly.find(params[:category_id])
      category_path = url_for(category_id: @category, only_path: true)
      if request.path != category_path
        return redirect_to category_path, status: :moved_permanently
      end
      true
    end

    # If the current category has redirecting enabled and no visible products,
    # redirect to its first descendant category, if any.
    def apply_redirecting
      if @category.redirecting? && @category.products.visible.empty?
        if first_child = @category.children.live.first
          return redirect_to show_category_path(first_child)
        end
      end
      false
    end

    # Find department by friendly id in `department_id`, including history.
    def find_department
      @department = @departments.friendly.find(params[:department_id])
      if request.path != show_department_path(@department)
        return redirect_to show_department_path(@department), status: :moved_permanently
      end
    end

    # Prepares a search for products in current category and its descendants.
    def prepare_category_search
      query = params[:product_search] || {}
      ProductSearch.new(query.merge(filter_params))
    end

    # Find product by friendly id in `product_id`.
    def find_product
      @product = current_store.products.live.friendly.find(params[:product_id])
    end

    # Find product by friendly id in `product_id`, redirecting to its
    # first variant if applicable.
    def find_first_variant_product
      selected = current_store.products.live.find_by(slug: params[:product_id])
      if selected.nil?
        return redirect_to front_path, notice: t('store.product_not_found')
      end
      @product = selected.first_variant
      if @product != selected
        return redirect_to show_product_path(@product, @category)
      end
    end

    def get_view_mode_setting(category)
      settings = if cookies[:view_mode_settings].present?
        JSON.parse(cookies[:view_mode_settings])
      else
        {}
      end
      key = ActionView::RecordIdentifier.dom_id(category)
      settings[key] || category.view_mode
    end

    # Category lookup includes categories in current store that are
    # live and have a category page contained in the store header,
    # thus they are navigable.
    def category_lookup_params
      {
        store: current_store,
        live: true,
        within: current_store.header
      }
    end

    # Restrict product lookup to live products in current store,
    # or member stores if defined (applies to portals).
    def product_lookup_params
      {
        store: current_store.member_stores.presence || current_store,
        live: true
      }
    end

    # Page lookup includes pages contained in the store header,
    # visible to the current group.
    # The search model sets further search criteria by itself.
    def page_lookup_params
      {
        store: current_store,
        group: current_group,
        within: current_store.header
      }
    end

    # Product filtering in current category including descendants.
    def filter_params
      {
        store: current_store,
        live: true,
        permitted_categories: @category.self_and_maybe_descendants
      }
    end
end
