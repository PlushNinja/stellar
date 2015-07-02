# encoding: UTF-8
# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20150622101529) do

  create_table "brands", force: :cascade do |t|
    t.integer  "erp_number", null: false
    t.string   "name"
    t.string   "slug"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "categories", force: :cascade do |t|
    t.integer  "brand_id",           null: false
    t.integer  "parent_category_id"
    t.string   "name"
    t.integer  "priority"
    t.datetime "created_at",         null: false
    t.datetime "updated_at",         null: false
  end

  add_index "categories", ["brand_id"], name: "index_categories_on_brand_id"
  add_index "categories", ["parent_category_id"], name: "index_categories_on_parent_category_id"

  create_table "image_types", force: :cascade do |t|
    t.string   "name"
    t.boolean  "bitmap",     default: true, null: false
    t.datetime "created_at",                null: false
    t.datetime "updated_at",                null: false
  end

  create_table "images", force: :cascade do |t|
    t.integer  "imageable_id"
    t.string   "imageable_type"
    t.integer  "image_type_id"
    t.integer  "priority"
    t.datetime "created_at",              null: false
    t.datetime "updated_at",              null: false
    t.string   "attachment_file_name"
    t.string   "attachment_content_type"
    t.integer  "attachment_file_size"
    t.datetime "attachment_updated_at"
  end

  add_index "images", ["image_type_id"], name: "index_images_on_image_type_id"
  add_index "images", ["imageable_type", "imageable_id"], name: "index_images_on_imageable_type_and_imageable_id"

  create_table "inventories", force: :cascade do |t|
    t.integer  "purpose",    default: 0, null: false
    t.string   "name"
    t.datetime "created_at",             null: false
    t.datetime "updated_at",             null: false
  end

  create_table "inventory_items", force: :cascade do |t|
    t.integer  "inventory_id", null: false
    t.string   "code",         null: false
    t.integer  "amount"
    t.datetime "created_at",   null: false
    t.datetime "updated_at",   null: false
  end

  add_index "inventory_items", ["code"], name: "index_inventory_items_on_code"
  add_index "inventory_items", ["inventory_id"], name: "index_inventory_items_on_inventory_id"

  create_table "order_items", force: :cascade do |t|
    t.integer  "order_id",   null: false
    t.integer  "product_id", null: false
    t.integer  "amount"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_index "order_items", ["order_id"], name: "index_order_items_on_order_id"
  add_index "order_items", ["product_id"], name: "index_order_items_on_product_id"

  create_table "order_types", force: :cascade do |t|
    t.integer  "inventory_id",                       null: false
    t.integer  "adjustment_multiplier", default: -1, null: false
    t.string   "name"
    t.datetime "created_at",                         null: false
    t.datetime "updated_at",                         null: false
  end

  create_table "orders", force: :cascade do |t|
    t.integer  "user_id",       null: false
    t.integer  "order_type_id", null: false
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  add_index "orders", ["order_type_id"], name: "index_orders_on_order_type_id"
  add_index "orders", ["user_id"], name: "index_orders_on_user_id"

  create_table "products", force: :cascade do |t|
    t.integer  "brand_id",      null: false
    t.integer  "category_id"
    t.string   "code"
    t.string   "customer_code"
    t.string   "name"
    t.text     "description"
    t.text     "memo"
    t.integer  "priority"
    t.datetime "created_at",    null: false
    t.datetime "updated_at",    null: false
  end

  add_index "products", ["brand_id"], name: "index_products_on_brand_id"
  add_index "products", ["category_id"], name: "index_products_on_category_id"

  create_table "users", force: :cascade do |t|
    t.integer  "brand_id",                         null: false
    t.string   "email",               default: "", null: false
    t.string   "encrypted_password",  default: "", null: false
    t.datetime "remember_created_at"
    t.integer  "sign_in_count",       default: 0,  null: false
    t.datetime "current_sign_in_at"
    t.datetime "last_sign_in_at"
    t.string   "current_sign_in_ip"
    t.string   "last_sign_in_ip"
    t.datetime "created_at",                       null: false
    t.datetime "updated_at",                       null: false
  end

  add_index "users", ["brand_id"], name: "index_users_on_brand_id"
  add_index "users", ["email"], name: "index_users_on_email", unique: true

end
