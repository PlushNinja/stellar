#encoding: utf-8

module StoreHelper

  def unit_price_string(price, unit)
    "#{humanized_money_with_symbol price} / #{unit}"
  end

  def humanized_money_range(range)
    min, max = range
    "#{humanized_money_with_symbol min} – #{humanized_money_with_symbol max}"
  end

  # Pretty-prints a hash from Product#stock.
  def product_stock_string(hash)
    hash.values.map do |i|
      content_tag(:span, class: i.klass, title: i.title, data: {toggle: 'tooltip'}) do
        content_tag(:span, i.adjustment == 0 ? i.amount || 0 :
          sprintf("%i(%+i)", i.amount || 0, i.adjustment))
      end
    end.join.html_safe
  end

  def property_string(product_properties)
    product_properties.map { |pp|
      content_tag(:span, pp.value, class: 'label label-default')
    }.join(' ').html_safe
  end
end
