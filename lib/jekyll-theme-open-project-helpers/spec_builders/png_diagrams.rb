require "fastimage"

# Recursively go through given list of nav_items, including any nested items,
# and return a flat array containing navigation items with path specified.
def get_nav_items_with_path(nav_items)
  items_with_path = []

  nav_items.each do |item|
    if item["path"]
      items_with_path.push(item)
    end

    if item["items"]
      items_with_path.concat(get_nav_items_with_path(item["items"]))
    end
  end

  items_with_path
end

def find_nav_items(diagram_nav_items, png_name_noext)
  diagram_nav_items.select do |item|
    item["path"].start_with?(png_name_noext)
  end
end

module Builder
  class PngDiagramPage < Jekyll::Page
    EXTRA_STYLESHEETS = [{
      "href" => "https://unpkg.com/leaflet@1.3.4/dist/leaflet.css",
      "integrity" => "sha512-puBpdR0798OZvTTbP4A8Ix/l+A4dHDD0DGqYW6RQ+9jxkRFclaxxQb/SJAWZfWAkuyeQUytO7+7N4QKrDh+drA==", # rubocop:disable Layout/LineLength
      "crossorigin" => "",
    }].freeze

    EXTRA_SCRIPTS = [{
      "src" => "https://unpkg.com/leaflet@1.3.4/dist/leaflet.js",
      "integrity" => "sha512-nMMmRyTVoLYqjP9hrbed9S+FzjZHW5gY1TWCHA5ckwXZBadntCNs8kEqAWdrb9O7rxbCaA4lKTIWjDXZxflOcA==", # rubocop:disable Layout/LineLength
      "crossorigin" => "",
    }].freeze

    def initialize(site, base, dir, data) # rubocop:disable Lint/MissingSuper
      @site = site
      @base = base
      @dir = dir
      @name = "index.html"

      process(@name)
      self.data ||= data

      self.data["extra_stylesheets"] = EXTRA_STYLESHEETS
      self.data["extra_scripts"] = EXTRA_SCRIPTS
      self.data["layout"] = "spec"
    end
  end

  def build_spec_pages(site, spec_info, source, dest, _opts)
    nav_items = get_nav_items_with_path(
      spec_info.data["navigation"]["items"],
    )

    pages, not_found_items = process_spec_images(site, source, nav_items,
                                                 dest, spec_info)

    not_found_items.each do |item|
      warn "SPECIFIED PNG NOT FOUND: #{item['title']}.png not found " \
           "at source as specified at (#{dest})."
    end

    pages
  end

  def process_spec_images(site, source, nav_items, dest, spec_info)
    pages = []
    not_found_items = nav_items.dup

    Dir.glob("#{source}/*.png") do |pngfile|
      png_name = File.basename(pngfile)
      png_name_noext = File.basename(png_name, File.extname(png_name))

      nav_item = find_nav_items(nav_items, png_name_noext)[0].clone

      if nav_item == nil
        warn "UNUSED PNG: #{File.basename(pngfile)} detected at source " \
             "without a corresponding navigation item at (#{dest})."
        next
      end

      not_found_items.delete_if { |item| item["title"] == nav_item["title"] }

      data = build_spec_page_data(pngfile, dest, png_name, nav_item,
                                  spec_info)

      pages << build_spec_page(site, dest, png_name_noext, data)
    end

    [pages, not_found_items]
  end

  def build_spec_page(site, spec_root, png_name_noext, data)
    page = PngDiagramPage.new(
      site,
      site.source,
      File.join(spec_root, png_name_noext),
      data,
    )

    stub_path = "#{File.dirname(__FILE__)}/png_diagram.html"
    page.content = File.read(stub_path)

    page
  end

  def build_spec_page_data(pngfile, spec_root, png_name, nav_item, spec_info)
    data = fill_image_data(pngfile, spec_info, spec_root, png_name)
      .merge(nav_item)

    data["title"] = "#{spec_info['title']}: #{nav_item['title']}"
    data["article_header_title"] = nav_item["title"].to_s

    data
  end

  def fill_image_data(pngfile, spec_info, spec_root, png_name)
    png_dimensions = FastImage.size(pngfile)
    data = spec_info.data.clone
    data["image_path"] = "/#{spec_root}/images/#{png_name}"
    data["image_width"] = png_dimensions[0]
    data["image_height"] = png_dimensions[1]
    data
  end
end
