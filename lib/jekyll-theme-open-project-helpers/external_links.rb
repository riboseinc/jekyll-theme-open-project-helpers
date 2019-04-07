require 'nokogiri'
require 'uri'

# Given hostname and content, updates <a> elements as follows:
#
# - Adds `rel` attribute
# - Appends inner markup for FontAwesome external link icon
#
# Only processes external links where `href` starts with "http"
# and target host does not include given site hostname.
def process_content(site_hostname, content, exclude_selectors=[])
  content = Nokogiri::HTML(content)
  content.css('body.site--project main a, body.site--hub.layout--post main a').each do |a|
    next unless a.get_attribute('href') =~ /\Ahttp/i
    next if a.get_attribute('href').include? site_hostname
    next if matches_one_of(a, exclude_selectors)
    a.set_attribute('rel', 'external')
    a.inner_html = "#{a.inner_html}<span class='ico-ext'><i class='fas fa-external-link-square-alt'></i></span>"
  end
  return content.to_s
end

# Returns true if Nokogiri’s Node matches one of selectors,
# otherwise return false
def matches_one_of(node, selectors)
  for selector in selectors
    if node.matches? selector
      return true
    end
  end
  return false
end

Jekyll::Hooks.register :documents, :post_render do |doc|
  site_hostname = URI(doc.site.config['url']).host
  unmarked_link_selectors = doc.site.config['unmarked_external_link_selectors']
  unless doc.asset_file?
    doc.output = process_content(site_hostname, doc.output, unmarked_link_selectors)
  end
end

Jekyll::Hooks.register :pages, :post_render do |page|
  site_hostname = URI(page.site.config['url']).host
  unmarked_link_selectors = page.site.config['unmarked_external_link_selectors']
  unless page.asset_file?
    page.output = process_content(site_hostname, page.output, unmarked_link_selectors)
  end
end
