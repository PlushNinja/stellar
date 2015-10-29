xml.order do
  xml.order_type @order.order_type
  xml.order_date @order.ordered_at.to_date
  xml.store_name @order.store_name
  xml.shipping_date @order.shipping_at

  xml.customer do
    xml.name @order.customer_name
    xml.company @order.company_name
    xml.contact_person @order.contact_person

    xml.billing do
      xml.address @order.billing_address
      xml.postalcode @order.billing_postalcode
      xml.city @order.billing_city
      xml.country @order.billing_country
    end

    xml.shipping do
      xml.address @order.shipping_address
      xml.postalcode @order.shipping_postalcode
      xml.city @order.shipping_city
      xml.country @order.shipping_country
    end
  end

  xml.notes @order.notes

  xml.order_items do
    @order.order_items.each do |item|
      xml.item do
        xml.product_code item.product_code
        xml.title item.product_title
        xml.subtitle item.product_subtitle
        xml.amount item.amount
        xml.sales_price item.price
      end
    end
  end
end
