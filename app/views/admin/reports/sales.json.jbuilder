json.data do
  json.array! @sales.by_product do |item|
    json.product_title link_to "<strong>#{item.product_title}</strong> #{item.product_subtitle}".html_safe, admin_product_path(item.product_id)
    json.product_code item.product_code
    json.amount item.amount
    json.value_sans_tax Money.new(item.value_sans_tax).format
  end
end
json.grand_total_sans_tax Money.new(@sales.grand_total_sans_tax).format
json.unit_count @sales.unit_count
json.product_count @sales.product_count
