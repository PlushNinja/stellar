#encoding: utf-8

require 'csv'

namespace :products do
  desc "Import Cardirad products from CSV input"
  task :cardirad, [:file] => :environment do |task, args|
    store = Store.find_by name: 'Cardirad Finland'
    tax_category = store.tax_categories.first

    store.products.destroy_all

    CSV.foreach(args.file,
      encoding: 'utf-8',
      col_sep: ';',
      skip_blanks: true,
      headers: [:title, :modified, nil, :ref, :gtin],
    ) do |row|
      product = store.products.create(
        code: row[:ref],
        customer_code: row[:gtin],
        title: row[:title],
        available_at: row[:modified],
        retail_price_cents: 0,
        tax_category: tax_category,
      )
      puts product
    end
  end
end
