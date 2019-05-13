require 'fileutils'

Jekyll::Hooks.register :pages, :post_write do |page|
  if page.path == "robots.txt" or page.path == "sitemap.xml"
    File.write(page.site.in_dest_dir(page.path), page.content, :mode => "wb")
  end
end

