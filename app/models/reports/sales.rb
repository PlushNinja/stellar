module Reports

  class Sales

    def initialize(search)
      @sort = search.raw_options[:sort]
      @items = search.results
    end

    def by_date
      @by_date ||= @items.select(
        'ordered_at AS date,
        SUM(amount) AS amount, SUM(total_value_cents) AS value'
      ).group(:ordered_at).reorder(:ordered_at)
    end

    def by_product
      @items.select(
        'products.id AS product_id, products.code AS product_code,
        products.title AS product_title, products.subtitle AS product_subtitle,
        SUM(amount) AS amount, SUM(total_value_cents) AS subtotal_value'
      ).group(:product_id).reorder(@sort)
    end

    def grand_total
      @items.sum(:total_value_cents)
    end

    def unit_count
      @items.sum(:amount)
    end

    def product_count
      @items.distinct.count(:product_id)
    end
  end
end
