# Uncomment this if you reference any of your controllers in activate
# require_dependency 'application'

class XapianSearchExtension < Spree::Extension
  version "1.0"
  description "Full text product search for Spree using acts_as_xapian"
  url "http://github.com/davidnorth/spree-xapian-search"

  def self.require_gems(config)
    config.gem "will_paginate"
  end
  
  def activate

    Product.class_eval do

      acts_as_xapian :texts => [:name, :description, :meta_keywords, :meta_description, :extra_search_texts]
      
      def extra_search_texts
        ''
      end

      attr_accessor :search_percent
      attr_accessor :search_weight

      # to be moved into spree some time
      def is_active?(some_time = Time.zone.now)
        deleted_at.nil? && available_on <= some_time
      end 

      def self.xsearch(query, options = {})
        options = {:per_page => 10}.update(options)
        options[:page] ||= 1
        
        total_matches = ActsAsXapian::Search.new([Product], query, :limit => options[:per_page]).matches_estimated
        total_pages = (total_matches / options[:per_page].to_f).ceil
        
        offset = options[:per_page] * (options[:page].to_i - 1)
        xapian_search = ActsAsXapian::Search.new([Product], query, :limit => options[:per_page], :offset => offset)

        products = xapian_search.results.map do |result|
          product = result[:model]
          product.search_percent = result[:percent]
          product.search_weight = result[:weight]
          product
        end
                
        products = products.select(&:is_active?)

        returning XapianResultEnumerator.new(options[:page], options[:per_page], total_matches) do |pager|
          pager.xapian_search = xapian_search
          pager.replace products
        end

      end
      
    end

    ProductsController.class_eval do
     
      @@excluded = %w[ an the a with on in to ]
 
      def search
        if params[:q]
          query = params[:q].map {|w| @@excluded.include?(w) ? w : w + '*' }.join(' ')
          @products = Product.xsearch(query, :page => params[:page], :per_page => 10)
        end
      end
      
    end
    
  end
end
