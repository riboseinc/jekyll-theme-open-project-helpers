require 'fastimage'

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

    Dir.glob("#{images_path}/*.png") do |pngfile|
      png_name = File.basename(pngfile)
      png_name_noext = File.basename(png_name, File.extname(png_name))

      nav_item = spec_info.data['navigation']['sections'].map { |section|
        section['items']
      } .flatten.select { |item| item['path'] == png_name_noext } [0].clone

      png_dimensions = FastImage.size(pngfile)
      data = spec_info.data.clone
      data['image_path'] = "/#{spec_root}/images/#{png_name}"
      data['image_width'] = png_dimensions[0]
      data['image_height'] = png_dimensions[1]
      data = data.merge(nav_item)

      data['title'] = "#{spec_info['title']}: #{nav_item['title']}"

      page = PngDiagramPage.new(
        site,
        site.source,
        File.join(spec_root, png_name_noext),
        data)
      page.content = File.read(stub_path)
      pages << page
    end

    return pages
  end

end
