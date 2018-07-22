module Jekyll
  module OpenProjectHelpers

    #
    # Infers from available content whether the site is a hub
    # or individual project site, and adds site-wide config variable
    # accessible as {{ site.is_hub }} in Liquid.
    #
    class SiteTypeVariableGenerator < Generator
      def generate(site)
        site.config['is_hub'] = false

        # If there’re projects defined, we assume it is indeed
        # a Jekyll Open Project hub site.
        if site.collections.key? 'projects'
          if site.collections['projects'] != nil
            if site.collections['projects'].docs.length > 0
              site.config['is_hub'] = true
            end
          end
        end
      end
    end

  end
end
