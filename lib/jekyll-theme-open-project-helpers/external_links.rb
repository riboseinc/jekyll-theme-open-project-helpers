require 'nokogiri'
require 'uri'

def process_content(site_hostname, content)
  content = Nokogiri::HTML(content)
  content.css('body.site--project main a, body.site--hub.layout--post main a').each do |a|
    next unless a.get_attribute('href') =~ /\Ahttp/i
    next if a.get_attribute('href').include? site_hostname
    a.set_attribute('rel', 'external')
    a.inner_html = "#{a.inner_html}<span class='ico-ext'><i class='fas fa-external-link-square'></i></span>"
  end
  return content.to_s
end

Jekyll::Hooks.register :documents, :post_render do |doc|
  site_hostname = URI(doc.site.config['url']).host
  unless doc.asset_file?
    doc.output = process_content(site_hostname, doc.output)
  end
end

Jekyll::Hooks.register :pages, :post_render do |page|
  site_hostname = URI(page.site.config['url']).host
  unless page.asset_file?
    page.output = process_content(site_hostname, page.output)
  end
end
