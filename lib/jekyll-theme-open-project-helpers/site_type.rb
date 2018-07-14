module Jekyll
  module OpenProjectHelpers

    def self.is_hub(site)

      # If there’re projects defined, we assume it is indeed
      # a Jekyll Open Project hub site.
      if site.collections.key? 'projects'
        if site.collections['projects'] != nil
          if site.collections['projects'].docs.length > 0
            return true
          end
        end
      end

      return false
    end

  end
end
