#encoding: utf-8

require 'csv'

IMPORT_PATH = Pathname.new '/etc/dropbox/Dropbox/extranet'

IMPORT_FILES = {

  # ASIAKAS,MIKA,NRO,OMALUOKIT,LUOKITUS2,TOIMLUOKIT,NIMI,NIMI2,MYYNTHINTA,
  # VARASTOLKM,VARATTULKM,TULOSSA,MUISTIO,MUISTIO2,MUISTIO4
  product: {
    file: 'www-nimike-utf8.csv',
    multiple: false,
    headers: [
      nil, :item_type_no, :code, nil, nil, nil,
      :title, :subtitle, :default_price,
      :quantity_on_hand, :quantity_reserved, :quantity_pending,
      nil, nil, :memo
    ],
  },
  # NRO,ASIAKNRO,ASIAKNIMI,ASIAKTNRO,MYYNTHINTA,VALUUTTA,MYYNTIERA,PAIVPVM
  stores: {
    file: 'www-nimike_asiakas-utf8.csv',
    multiple: true,
    headers: [
      :code, :erp_number, :store_name, :customer_code, :sales_price
    ],
  },
  # PAANUMERO,ALINUMERO,PAATMP,ALITMP,LKM,TARVE1,TARVE2,BTARVE1,BTARVE2,SELITE
  structure: {
    file: 'www-nimike_rakenne-utf8.csv',
    multiple: true,
    headers: [:code, :component_code, nil, nil, :quantity]
  },
}

namespace :matfox do
  desc "Import data from Matfox"
  task import: :environment do |task, args|

    Product.transaction do
      import_data.each do |code, data|
        next if data[:product].nil? or data[:stores].nil?

        # Find or create the product by product code separately in each store.
        data[:stores].each do |row|
          store = Store.where(erp_number: row[:erp_number]).first
          next if store.nil?

          product = Product.find_or_initialize_by(code: code, store: store)
          product.save(validate: false)
          product.update_columns(
            title: data[:product][:title].try(:mb_chars).try(:titleize),
            subtitle: data[:product][:subtitle].try(:mb_chars).try(:titleize),
            memo: data[:product][:memo],
            customer_code: row[:customer_code],
          )
          next if data[:structure].nil?

          # Assign relationships between code and part_code.
          data[:structure].each do |row|
            component = Product.find_by(code: row[:component_code])
            next if component.nil?
            relationship = product.relationships
              .find_or_create_by(product: component)
            relationship.update_columns(quantity: row[:quantity].to_i)
          end
        end

        # Update inventory items to match quantities.
        pending_item = Inventory.for(:manufacturing)
          .inventory_items.find_or_create_by(code: code)
        pending_item.update(amount: data[:product][:quantity_pending])

        on_hand_item = Inventory.for(:shipping)
          .inventory_items.find_or_create_by(code: code)
        on_hand_item.update(amount: data[:product][:quantity_on_hand])
      end
    end
  end

  # Import all import files into a hash of hashes, where the top level key 'i'
  # is the field 'code', the second level key 'j' is the IMPORT_FILES key.
  # Import file options may specify either single or multiple record mode.
  def import_data
    data = {}
    IMPORT_FILES.each do |j, options|
      CSV.foreach(IMPORT_PATH.join(options[:file]), headers: options[:headers]) do |row|
        i = row[:code]
        data[i] ||= {}
        if options[:multiple]
          data[i][j] ||= []
          data[i][j] << row
        else
          data[i][j] = row
        end
      end
    end
    data
  end
end
