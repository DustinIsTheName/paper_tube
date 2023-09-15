class OrderController < ApplicationController

  skip_before_action :verify_authenticity_token

  def change_carton_inventory
    puts Colorize.magenta(params)

    mai_location_id = 28530180196
    ptc_location_id = 15897231460

    verified = verify_webhook(request.body.read, request.headers["HTTP_X_SHOPIFY_HMAC_SHA256"])

    if verified
      fulfillment_orders = ShopifyAPI::FulfillmentOrder.all order_id:(params["id"])

      for line_item in params["line_items"]
        # product = ShopifyAPI::Product.find id: 2572782862436 # <==== test product
        # get the Shopify Product purchased in this line item
        product = ShopifyAPI::Product.find id: line_item["product_id"]  # qw12 TESTING!!
        line_item_location_id = fulfillment_orders.select{|fo| fo.line_items.select{|i| i["line_item_id"] == line_item["id"]}.count > 0}.first&.assigned_location_id

        # identify the tube and carton variant 
        carton_variant_ids = product.variants.select{|v| v.option1&.downcase&.include? "carton" or v.option2&.downcase&.include? "carton" or v.option3&.downcase&.include? "carton"}.map{|v| v.id}
        purchased_carton_variant = product.variants.select{|v| v.id == line_item["variant_id"]}.first
        # remove variable tubes_per_carton below

        if carton_variant_ids.include? line_item["variant_id"] # qw12 TESTING!! OR/AND
          order = Order.find_by_order_id params["order"]["id"]
          unless order

            for carton_variant_id in carton_variant_ids
              
              carton_variant = product.variants.select{|v| v.id == carton_variant_id}.first

              # get InventoryLevel object for the tube variant
              quantity = line_item["quantity"]
              inventory_levels = ShopifyAPI::InventoryLevel.all inventory_item_ids: carton_variant.inventory_item_id

              mai_inventory_level = inventory_levels.select{|i| i.location_id == mai_location_id}.first
              ptc_inventory_level = inventory_levels.select{|i| i.location_id == ptc_location_id}.first

              # change InventoryLevel object for the tube variant
              if carton_variant.inventory_management == 'shopify'

                unless line_item["variant_id"] == carton_variant_id
                  if line_item_location_id == mai_location_id
                    if mai_inventory_level.adjust(
                        location_id: mai_inventory_level.location_id, 
                        inventory_item_id: mai_inventory_level.inventory_item_id, 
                        available_adjustment: quantity * -1)
                                # save order so it isn't duplicated
                      order = Order.new
                      order.order_id = params["order"]["id"]
                      order.save
                      puts Colorize.green("Updated #{product.title} - #{carton_variant.title}")
                    end
                  end

                  if line_item_location_id == ptc_location_id
                    if ptc_inventory_level.adjust(
                        location_id: ptc_inventory_level.location_id, 
                        inventory_item_id: ptc_inventory_level.inventory_item_id, 
                        available_adjustment: quantity * -1)
                                # save order so it isn't duplicated
                      order = Order.new
                      order.order_id = params["order"]["id"]
                      order.save
                      puts Colorize.green("Updated #{product.title} - #{carton_variant.title}")
                    end
                  end
                end

              end

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

        # identify the carton variants and purchased carton variant
        carton_variant_ids = product.variants.select{|v| v.option1&.downcase&.include? "carton" or v.option2&.downcase&.include? "carton" or v.option3&.downcase&.include? "carton"}.map{|v| v.id}
        purchased_carton_variant = product.variants.select{|v| v.id == line_item["variant_id"]}.first

        if tubes_per_carton and carton_variant_ids.include? line_item["variant_id"] and refund_item["restock_type"] != "no_restock" # qw12 TESTING!! OR/AND
          order = Order.find_by_order_id "re_#{params["order"]["id"]}"
          unless order

            for carton_variant_id in carton_variant_ids
              unless line_item["variant_id"] == carton_variant_id
                carton_variant = product.variants.select{|v| v.id == carton_variant_id}.first
                
                # get InventoryLevel object for the tube variant
                quantity = line_item["quantity"]
                inventory_levels = ShopifyAPI::InventoryLevel.all inventory_item_ids: carton_variant.inventory_item_id

                # change InventoryLevel object for the tube variant
                if carton_variant.inventory_management = 'shopify'
                  if inventory_levels[0].adjust(
                      location_id: inventory_levels[0].location_id, 
                      inventory_item_id: inventory_levels[0].inventory_item_id, 
                      available_adjustment: quantity)
                              # save order so it isn't duplicated
                    order = Order.new
                    order.order_id = "re_#{params["order"]["id"]}"
                    order.save
                    puts Colorize.magenta("refunded #{product.title} - #{carton_variant.title}")
                  end
                end

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