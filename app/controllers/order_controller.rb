class OrderController < ApplicationController

  skip_before_action :verify_authenticity_token

  def change_carton_inventory
    puts Colorize.magenta(params)

    verified = verify_webhook(request.body.read, request.headers["HTTP_X_SHOPIFY_HMAC_SHA256"])

    if verified

      for line_item in params["line_items"]
        # product = ShopifyAPI::Product.find id: 8129157857554 # <==== test product
        # get the Shopify Product purchased in this line item
        product = ShopifyAPI::Product.find id: line_item["product_id"]  # qw12 TESTING!!

        # identify the tube and carton variant 
        carton_variant_ids = product.variants.select{|v| v.option1&.downcase&.include? "carton" or v.option2&.downcase&.include? "carton" or v.option3&.downcase&.include? "carton"}.map{|v| v.id}
        tube_variant = product.variants.select{|v| v.option1&.downcase == "individual" or v.option2&.downcase == "individual" or v.option3&.downcase == "individual"}.first

        # get the number of tubes per carton
        metafields = ShopifyAPI::Metafield.all(metafield: {"owner_id" => product.id, "owner_resource" => "product"})
        tubes_per_carton_metafield = metafields.select{|m| m.key == "tube_per_carton" and m.namespace == "custom"}.first
        tubes_per_carton = tubes_per_carton_metafield.value if tubes_per_carton_metafield

        puts Colorize.cyan("tubes_per_carton: #{tubes_per_carton}, current/carton id: #{line_item["variant_id"]}/#{carton_variant_ids}")
        if tubes_per_carton and carton_variant_ids.include? line_item["variant_id"] # qw12 TESTING!! OR/AND
          order = Order.find_by_order_id params["order"]["id"]
          unless order
            # get InventoryLevel object for the tube variant
            tube_quantity = line_item["quantity"] * tubes_per_carton
            inventory_levels = ShopifyAPI::InventoryLevel.all inventory_item_ids: tube_variant.inventory_item_id

            # change InventoryLevel object for the tube variant
            if tube_variant.inventory_management = 'shopify'
              if inventory_levels[0].adjust(
                  location_id: inventory_levels[0].location_id, 
                  inventory_item_id: inventory_levels[0].inventory_item_id, 
                  available_adjustment: tube_quantity * -1)
                          # save order so it isn't duplicated
                order = Order.new
                order.order_id = params["order"]["id"]
                order.save
                puts Colorize.green("Updated #{product.title} - #{tube_variant.title}")
              end
            end
          end

        end

        # add Inventory back if the tube variant is purchased
        if line_item["variant_id"] == tube_variant&.id
          # qw12
          tube_quantity = line_item["quantity"]
          inventory_levels = ShopifyAPI::InventoryLevel.all inventory_item_ids: tube_variant.inventory_item_id

          order = Order.find_by_order_id params["order"]["id"]
          unless order
            # change InventoryLevel object for the tube variant
            if tube_variant.inventory_management = 'shopify'
              if inventory_levels[0].adjust(
                  location_id: inventory_levels[0].location_id, 
                  inventory_item_id: inventory_levels[0].inventory_item_id, 
                  available_adjustment: tube_quantity)
                          # save order so it isn't duplicated
                order = Order.new
                order.order_id = params["order"]["id"]
                order.save
                puts Colorize.green("Returned inv #{product.title} - #{tube_variant.title}")
              end
            end
          end
        end

        screen_printing = false
        ptc_found = false
        for line_item in params["line_items"]
          inv = ShopifyAPI::InventoryLevel.all inventory_item_ids: line_item["variant_id"]
          if inv.length > 0
            l = ShopifyAPI::Location.find id: inv.first.location_id
            if l.name == "PTC"
              ptc_found = true
            end
          end
          if line_item["title"] == "Screen Printing"
            screen_printing = true
          end
        end

        if ptc_found or screen_printing
          order = ShopifyAPI::Order.find id: params["id"]
          if ptc_found
            puts Colorize.green "add PTC tag"
            if order.tags.length == 0
              order.tags = "PTC"
            else
              order.tags << ", PTC"
            end
          end
          if screen_printing
            puts Colorize.green "add ScreenPrinting tag"
            if order.tags.length == 0
              order.tags = "ScreenPrinting"
            else
              order.tags << ", ScreenPrinting"
            end
          end
          order.save
        end

        if Date.today.day == 1
          Order.where("created_at < ?", 7.days.ago).destroy_all
        end
      end
    end

    head :ok, content_type: "text/html"
  end

  def refund_carton_inventory
    puts Colorize.magenta(params)

    verified = verify_webhook(request.body.read, request.headers["HTTP_X_SHOPIFY_HMAC_SHA256"])
    if verified
      for refund_item in params["refund_line_items"]
        line_item = refund_item["line_item"]
        # product = ShopifyAPI::Product.find id: 8129157857554 # <==== test product
        # get the Shopify Product purchased in this line item
        product = ShopifyAPI::Product.find id: line_item["product_id"] # qw12 TESTING!!

        # identify the tube and carton variant 
        carton_variant_ids = product.variants.select{|v| v.option1&.downcase&.include? "carton" or v.option2&.downcase&.include? "carton" or v.option3&.downcase&.include? "carton"}.map{|v| v.id}
        tube_variant = product.variants.select{|v| v.option1&.downcase == "individual" or v.option2&.downcase == "individual" or v.option3&.downcase == "individual"}.first

        # get the number of tubes per carton
        metafields = ShopifyAPI::Metafield.all(metafield: {"owner_id" => product.id, "owner_resource" => "product"})
        tubes_per_carton_metafield = metafields.select{|m| m.key == "tube_per_carton" and m.namespace == "custom"}.first
        tubes_per_carton = tubes_per_carton_metafield.value if tubes_per_carton_metafield

        puts Colorize.cyan("tubes_per_carton: #{tubes_per_carton}, current/carton id: #{line_item["variant_id"]}/#{carton_variant_ids}")
        if tubes_per_carton and carton_variant_ids.include? line_item["variant_id"] and refund_item["restock_type"] != "no_restock" # qw12 TESTING!! OR/AND
          order = Order.find_by_order_id "re_#{params["order"]["id"]}"
          unless order
            # get InventoryLevel object for the tube variant
            tube_quantity = line_item["quantity"] * tubes_per_carton
            inventory_levels = ShopifyAPI::InventoryLevel.all inventory_item_ids: tube_variant.inventory_item_id

            # change InventoryLevel object for the tube variant
            if tube_variant.inventory_management = 'shopify'
              if inventory_levels[0].adjust(
                  location_id: inventory_levels[0].location_id, 
                  inventory_item_id: inventory_levels[0].inventory_item_id, 
                  available_adjustment: tube_quantity)
                          # save order so it isn't duplicated
                order = Order.new
                order.order_id = "re_#{params["order"]["id"]}"
                order.save
                puts Colorize.magenta("refunded #{product.title} - #{tube_variant.title}")
              end
            end
          end

        end
      end
    end

    head :ok, content_type: "text/html"
  end

  private

    def verify_webhook(data, hmac_header)
      digest  = OpenSSL::Digest.new('sha256')
      calculated_hmac = Base64.encode64(OpenSSL::HMAC.digest(digest, ENV["WEBHOOK_SECRET"], data)).strip
      if calculated_hmac == hmac_header
        puts Colorize.green("Verified!")
      else
        puts Colorize.red("Invalid verification!")
      end
      calculated_hmac == hmac_header
    end

end