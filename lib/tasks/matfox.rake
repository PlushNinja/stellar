#encoding: utf-8

require 'csv'

IMPORT_PATH = Pathname.new '/home/blade/Dropbox/extranet'

IMPORT_FILES = {

  # ASIAKAS,MIKA,NRO,OMALUOKIT,LUOKITUS2,TOIMLUOKIT,NIMI,NIMI2,MYYNTHINTA,
  # VARASTOLKM,VARATTULKM,TULOSSA,MUISTIO,MUISTIO2,MUISTIO4
  product: {
    file: 'www-nimike-utf8.csv',
    multiple: false,
    headers: [
      nil, :item_type_no, :code, nil, nil, nil,
      :name, :description, nil, nil, nil, nil,
      :memo_1, :memo_2, :memo_3
    ],
  },
  # NRO,ASIAKNRO,ASIAKNIMI,ASIAKTNRO,MYYNTHINTA,VALUUTTA,MYYNTIERA,PAIVPVM
  brands: {
    file: 'www-nimike_asiakas-utf8.csv',
    multiple: true,
    headers: [
      :code, :erp_number, :brand_name, :foreign_code, :sales_price
    ],
  },
  # PAANUMERO,ALINUMERO,PAATMP,ALITMP,LKM,TARVE1,TARVE2,BTARVE1,BTARVE2,SELITE
  structure: {
    file: 'www-nimike_rakenne-utf8.csv',
    multiple: true,
    headers: [:code, :part_code, nil, nil, :amount]
  },
  # NRO,HYLLY,VARASTOLKM,VARATTULKM,TULOSSA,TILAUSPIST,INVENTLKM,INVENTPVM,VARHINTA
  #inventory: {
  #  file: 'www-nimike_varasto-utf8.csv',
  #  headers: []
  #},
}

namespace :matfox do
  desc "Import data from Matfox"
  task :import => :environment do |task, args|

    #pp import_data
    import_data.each do |code, data|
      next if data[:product].nil? or data[:brands].nil?

      # Find of create the product by product code separately in each brand.
      data[:brands].each do |row|
        brand = Brand.where(erp_number: row[:erp_number]).first
        next if brand.nil?

        product = Product.find_or_initialize_by(code: code, brand: brand)
        product.save(validate: false)
        product.update_columns(
          name: data[:product][:name],
          description: data[:product][:description],
          memo: [
            data[:product][:memo_1],
            data[:product][:memo_2],
            data[:product][:memo_3]
          ].join("\n"),
        )
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
