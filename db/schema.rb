# frozen_string_literal: true
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

ActiveRecord::Schema.define(version: 20170605112058) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "applications", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_applications_on_tenant_id"
  end

  create_table "entries", force: :cascade do |t|
    t.json "data"
    t.bigint "tenant_id", null: false
    t.bigint "model_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["model_id"], name: "index_entries_on_model_id"
    t.index ["tenant_id"], name: "index_entries_on_tenant_id"
  end

  create_table "integration_states", force: :cascade do |t|
    t.datetime "started_at"
    t.datetime "finished_at"
    t.boolean "success"
    t.bigint "model_id", null: false
    t.bigint "entry_id"
    t.bigint "integration_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["entry_id"], name: "index_integration_states_on_entry_id"
    t.index ["integration_id"], name: "index_integration_states_on_integration_id"
    t.index ["model_id", "integration_id"], name: "index_integration_states_on_model_id_and_integration_id", unique: true
    t.index ["model_id"], name: "index_integration_states_on_model_id"
  end

  create_table "integrations", force: :cascade do |t|
    t.json "configuration"
    t.string "type", null: false
    t.bigint "tenant_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id", "type"], name: "index_integrations_on_tenant_id_and_type", unique: true
    t.index ["tenant_id"], name: "index_integrations_on_tenant_id"
  end

  create_table "metrics", force: :cascade do |t|
    t.bigint "service_id", null: false
    t.bigint "tenant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["service_id"], name: "index_metrics_on_service_id"
    t.index ["tenant_id"], name: "index_metrics_on_tenant_id"
  end

  create_table "models", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.string "record_type"
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id"], name: "index_models_on_record_type_and_record_id", unique: true
    t.index ["tenant_id"], name: "index_models_on_tenant_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.bigint "model_id", null: false
    t.json "data", null: false
    t.bigint "tenant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["model_id"], name: "index_notifications_on_model_id"
    t.index ["tenant_id"], name: "index_notifications_on_tenant_id"
  end

  create_table "services", force: :cascade do |t|
    t.bigint "tenant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["tenant_id"], name: "index_services_on_tenant_id"
  end

  create_table "tenants", force: :cascade do |t|
    t.string "endpoint", null: false
    t.string "access_token", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "update_states", force: :cascade do |t|
    t.datetime "started_at"
    t.datetime "finished_at"
    t.boolean "success", default: false, null: false
    t.bigint "model_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["model_id"], name: "index_update_states_on_model_id", unique: true
  end

  create_table "usage_limits", force: :cascade do |t|
    t.bigint "metric_id", null: false
    t.integer "plan_id", null: false
    t.bigint "tenant_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["metric_id"], name: "index_usage_limits_on_metric_id"
    t.index ["tenant_id"], name: "index_usage_limits_on_tenant_id"
  end

  add_foreign_key "applications", "tenants"
  add_foreign_key "entries", "models"
  add_foreign_key "entries", "tenants"
  add_foreign_key "integration_states", "entries"
  add_foreign_key "integration_states", "integrations"
  add_foreign_key "integration_states", "models"
  add_foreign_key "integrations", "tenants"
  add_foreign_key "metrics", "services"
  add_foreign_key "metrics", "tenants"
  add_foreign_key "models", "tenants"
  add_foreign_key "notifications", "models"
  add_foreign_key "notifications", "tenants"
  add_foreign_key "services", "tenants"
  add_foreign_key "update_states", "models"
  add_foreign_key "usage_limits", "metrics"
  add_foreign_key "usage_limits", "tenants"
end
