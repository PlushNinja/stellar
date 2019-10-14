module StoreHelper

  def product_search_params
    request.params.slice(:product_search)
  end

  # Generates a product url that can be in another store
  # if the current store is a portal.
  def product_url(product, category = nil)
    if current_store.portal?
      host = product.store.hostname_at(current_store)
      show_product_url(product, host: host.to_s)
    else
      show_product_path(product, category)
    end
  end

  def fuzzy_amount(amount)
    amount > 25 ? t('number.more_than', number: 25) : amount
  end

  # Returns a potentially fuzzy stock reading for given amount.
  def product_stock(amount, fuzzy = false)
    fuzzy ? fuzzy_amount(amount) : amount
  end

  def money(amount)
    return nil if amount.nil?
    humanized_money_with_symbol(amount)
  end

  def fancy_price(price)
    return nil if price.nil?
    amount = incl_tax? ? price.with_tax : price.sans_tax
    sep = amount.decimal_mark
    units, subunits = humanized_money(amount).split sep
    capture do
      concat units
      concat content_tag(:span, sep, class: 'sep')
      concat content_tag(:span, subunits, class: 'cents')
      concat currency_symbol
    end
  end

  def fancy_price_range(from, to)
    capture do
      concat fancy_price(from)
      if from != to
        concat '–'
        concat fancy_price(to)
      end
    end
  end

  # Displays a fancy price tag with a single final price,
  # or dual special/regular prices.
  def price_tag(final_price, regular_price = nil)
    content_tag(:span, class: regular_price && 'special-price') do
      concat fancy_price(final_price)
      if regular_price
        concat content_tag(:span, class: 'regular-price') { fancy_price(regular_price) }
      end
    end
  end

  # Displays a fancy price range from two final prices.
  def price_range(from, to)
    content_tag(:span, class: 'price-range') do
      fancy_price_range(from, to)
    end
  end

  def unit_pricing_string(price, quantity, unit)
    unless quantity.zero?
      capture do
        concat price_tag(price / quantity)
        concat '/'
        concat unit
      end
    end
  end

  def dynamic_navbar?
    @page&.dynamic_navbar?
  end
end
