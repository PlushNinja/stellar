json.array!(@orders) do |order|
  json.extract! order, :id, :user_id, :order_type_id
  json.url admin_order_url(order, format: :json)
end
