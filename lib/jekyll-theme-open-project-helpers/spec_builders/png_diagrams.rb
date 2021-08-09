require 'fastimage'

# Recursively go through given list of nav_items, including any nested items,
# and return a flat array containing navigation items with path specified.
def get_nav_items_with_path(nav_items)
  items_with_path = []

  for item in nav_items do
    if item['path']
      items_with_path.push(item)
    end

    if item['items']
      items_with_path.concat(get_nav_items_with_path(item['items']))
    end
  end

  return items_with_path
end

module Builder

  class PngDiagramPage < Jekyll::Page
    def initialize(site, base, dir, data)
      @site = site
      @base = base
      @dir = dir
      @name = 'index.html'

      self.process(@name)
      self.data ||= data

      self.data['extra_stylesheets'] = [{
        "href" => "https://unpkg.com/leaflet@1.3.4/dist/leaflet.css",
        "integrity" => "sha512-puBpdR0798OZvTTbP4A8Ix/l+A4dHDD0DGqYW6RQ+9jxkRFclaxxQb/SJAWZfWAkuyeQUytO7+7N4QKrDh+drA==",
        "crossorigin" => "",
      }]

      self.data['extra_scripts'] = [{
        "src" => "https://unpkg.com/leaflet@1.3.4/dist/leaflet.js",
        "integrity" => "sha512-nMMmRyTVoLYqjP9hrbed9S+FzjZHW5gY1TWCHA5ckwXZBadntCNs8kEqAWdrb9O7rxbCaA4lKTIWjDXZxflOcA==",
        "crossorigin" => "",
      }]

      self.data['layout'] = 'spec'
    end
  end

  def build_spec_pages(site, spec_info, source, destination, opts)
    images_path = source
    spec_root = destination
    stub_path = "#{File.dirname(__FILE__)}/png_diagram.html"
    pages = []

    diagram_nav_items = get_nav_items_with_path(spec_info.data['navigation']['items'])
    not_found_items = diagram_nav_items.dup

    Dir.glob("#{images_path}/*.png") do |pngfile|
      png_name = File.basename(pngfile)
      png_name_noext = File.basename(png_name, File.extname(png_name))

      nav_item = diagram_nav_items.select { |item|
        item['path'].start_with?(png_name_noext)
      } [0].clone

      if nav_item == nil
        warn "UNUSED PNG: #{png_name} detected at source without a corresponding navigation item at (#{spec_root})."
        next
      end

      not_found_items.delete_if { |item| item["title"] == nav_item["title"] }

      png_dimensions = FastImage.size(pngfile)
      data = spec_info.data.clone
      data['image_path'] = "/#{spec_root}/images/#{png_name}"
      data['image_width'] = png_dimensions[0]
      data['image_height'] = png_dimensions[1]

      data = data.merge(nav_item)

      data['title'] = "#{spec_info['title']}: #{nav_item['title']}"
      data['article_header_title'] = "#{nav_item['title']}"

      page = PngDiagramPage.new(
        site,
        site.source,
        File.join(spec_root, png_name_noext),
        data)
      page.content = File.read(stub_path)
      pages << page
    end

    not_found_items.each do |item|
      title = item["title"]
      warn "SPECIFIED PNG NOT FOUND: #{title}.png not found at source as specified at (#{spec_root})."
    end

    return pages
  end

end
