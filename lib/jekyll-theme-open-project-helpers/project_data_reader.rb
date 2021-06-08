require 'fileutils'

module Jekyll
  module OpenProjectHelpers

    DEFAULT_DOCS_SUBTREE = 'docs'

    DEFAULT_REPO_REMOTE_NAME = 'origin'
    DEFAULT_REPO_BRANCH = 'main'
    # Can be overridden by default_repo_branch in site config.
    # Used by shallow_git_checkout.

    class NonLiquidDocument < Jekyll::Document
      def render_with_liquid?
        return false
      end
    end

    class CollectionDocReader < Jekyll::DataReader

      def read(dir, collection)
        read_project_subdir(dir, collection)
      end

      def read_project_subdir(dir, collection, nested=false)
        return unless File.directory?(dir) && !@entry_filter.symlink?(dir)

        entries = Dir.chdir(dir) do
          Dir["*.{adoc,md,markdown,html,svg,png}"] + Dir["*"].select { |fn| File.directory?(fn) }
        end

        entries.each do |entry|
          path = File.join(dir, entry)

          Jekyll.logger.debug("OPF:", "Reading entry #{path}")

          if File.directory?(path)
            read_project_subdir(path, collection, nested=true)

          elsif nested or (File.basename(entry, '.*') != 'index')
            ext = File.extname(path)
            if ['.adoc', '.md', '.markdown'].include? ext
              doc = NonLiquidDocument.new(path, :site => @site, :collection => collection)
              doc.read

              # Add document to Jekyll document database if it refers to software or spec
              # (as opposed to be some random nested document within repository source, like a README)
              doc_url_parts = doc.url.split('/')
              Jekyll.logger.debug("OPF:", "Reading document in collection #{collection.label} with URL #{doc.url} (#{doc_url_parts.size} parts)")
              if collection.label != 'projects' or doc_url_parts.size == 5
                Jekyll.logger.debug("OPF:", "Adding document with URL: #{doc.url}")
                collection.docs << doc
              else
                Jekyll.logger.debug("OPF:", "Did NOT add document with URL (possibly nesting level doesn’t match): #{doc.url}")
              end
            else
              Jekyll.logger.debug("OPF:", "Adding static file: #{path}")
              collection.files << Jekyll::StaticFile.new(
                @site,
                @site.source,
                Pathname.new(File.dirname(path)).relative_path_from(Pathname.new(@site.source)).to_s,
                File.basename(path),
                collection)
            end
          end
        end
      end
    end


    #
    # Below deals with fetching each open project’s data from its site’s repo
    # (such as posts, template includes, software and specs)
    # and reading it into 'projects' collection docs.
    #

    class OpenProjectReader < JekyllData::Reader

      # TODO: Switch to @site.config?
      @@siteconfig = Jekyll.configuration({})

      def read
        super
        if @site.config['is_hub']
          fetch_and_read_projects
        else
          fetch_and_read_software('software')
          fetch_and_read_specs('specs', true)
          fetch_hub_logo
        end
      end

      private

      def fetch_hub_logo
        if @site.config.key? 'parent_hub' and @site.config['parent_hub'].key? 'git_repo_url'
          git_shallow_checkout(
            File.join(@site.source, 'parent-hub'),
            @site.config['parent_hub']['git_repo_url'],
            ['assets', 'title.html'],
            @site.config['parent_hub']['git_repo_branch'])
        end
      end

      def fetch_and_read_projects
        project_indexes = @site.collections['projects'].docs.select do |doc|
          pieces = doc.id.split('/')
          pieces.length == 4 and pieces[1] == 'projects' and pieces[3] == 'index'
        end
        project_indexes.each do |project|
          project_path = project.path.split('/')[0..-2].join('/')

          git_shallow_checkout(
            project_path,
            project['site']['git_repo_url'],
            ['assets', '_posts', '_software', '_specs'],
            project['site']['git_repo_branch'])

          
          Jekyll.logger.debug("OPF:", "Reading files in project #{project_path}")

          CollectionDocReader.new(site).read(
            project_path,
            @site.collections['projects'])

          fetch_and_read_software('projects')
          fetch_and_read_specs('projects')
        end
      end

      def build_and_read_spec_pages(collection_name, index_doc, build_pages=false)
        item_name = index_doc.id.split('/')[-1]

        repo_checkout = nil
        src = index_doc.data['spec_source']
        repo_url = src['git_repo_url']
        repo_subtree = src['git_repo_subtree']
        repo_branch = src['git_repo_branch']
        build = src['build']
        engine = build['engine']
        engine_opts = build['options'] || {}

        spec_checkout_path = "#{index_doc.path.split('/')[0..-2].join('/')}/#{item_name}"
        spec_root = if repo_subtree
                      "#{spec_checkout_path}/#{repo_subtree}"
                    else
                      spec_checkout_path
                    end

        repo_checkout = git_shallow_checkout(spec_checkout_path, repo_url, [repo_subtree], repo_branch)

        if repo_checkout[:success]
          if build_pages
            builder = Jekyll::OpenProjectHelpers::SpecBuilder::new(
              @site,
              index_doc,
              spec_root,
              "specs/#{item_name}",
              engine,
              engine_opts)

            builder.build()
            builder.built_pages.each do |page|
              @site.pages << page
            end

            CollectionDocReader.new(site).read(
              spec_checkout_path,
              @site.collections[collection_name])
          end

          index_doc.merge_data!({ 'last_update' => repo_checkout[:modified_at] })
        end
      end

      def fetch_and_read_specs(collection_name, build_pages=false)
        # collection_name would be either specs or (for hub site) projects

        Jekyll.logger.debug("OPF:", "Fetching specs for items in collection #{collection_name} (if it exists)")

        return unless @site.collections.key?(collection_name)

        Jekyll.logger.debug("OPF:", "Fetching specs for items in collection #{collection_name}")

        # Get spec entry points
        entry_points = @site.collections[collection_name].docs.select do |doc|
          doc.data['spec_source']
        end

        if entry_points.size < 1
          Jekyll.logger.info("OPF:", "Fetching specs for items in collection #{collection_name}: No entry points")
        end

        entry_points.each do |index_doc|
          Jekyll.logger.debug("OPF:", "Fetching specs: entry point #{index_doc.id} in collection #{collection_name}")
          build_and_read_spec_pages(collection_name, index_doc, build_pages)
        end
      end

      def fetch_and_read_software(collection_name)
        # collection_name would be either software or (for hub site) projects

        Jekyll.logger.debug("OPF:", "Fetching software for items in collection #{collection_name} (if it exists)")

        return unless @site.collections.key?(collection_name)

        Jekyll.logger.debug("OPF:", "Fetching software for items in collection #{collection_name}")

        entry_points = @site.collections[collection_name].docs.select do |doc|
          doc.data['repo_url']
        end

        if entry_points.size < 1
          Jekyll.logger.info("OPF:", "Fetching software for items in collection #{collection_name}: No entry points")
        end

        entry_points.each do |index_doc|
          item_name = index_doc.id.split('/')[-1]
          Jekyll.logger.debug("OPF:", "Fetching software: entry point #{index_doc.id} in collection #{collection_name}")

          docs = index_doc.data['docs']
          main_repo = index_doc.data['repo_url']
          main_repo_branch = index_doc.data['repo_branch']

          sw_docs_repo = (if docs then docs['git_repo_url'] end) || main_repo
          sw_docs_subtree = (if docs then docs['git_repo_subtree'] end) || DEFAULT_DOCS_SUBTREE
          sw_docs_branch = (if docs then docs['git_repo_branch'] end) || nil

          docs_path = "#{index_doc.path.split('/')[0..-2].join('/')}/#{item_name}"

          sw_docs_checkout = git_shallow_checkout(docs_path, sw_docs_repo, [sw_docs_subtree], sw_docs_branch)

          if sw_docs_checkout[:success]
            CollectionDocReader.new(site).read(
              docs_path,
              @site.collections[collection_name])
          end

          # Get last repository modification timestamp.
          # Fetch the repository for that purpose,
          # unless it’s the same as the repo where docs are.
          if !sw_docs_checkout[:success] or sw_docs_repo != main_repo
            repo_path = "#{index_doc.path.split('/')[0..-2].join('/')}/_#{item_name}_repo"
            repo_checkout = git_shallow_checkout(repo_path, main_repo, [], main_repo_branch)
            index_doc.merge_data!({ 'last_update' => repo_checkout[:modified_at] })
          else
            index_doc.merge_data!({ 'last_update' => sw_docs_checkout[:modified_at] })
          end
        end
      end

      def git_shallow_checkout(repo_path, remote_url, sparse_subtrees, branch_name)
        # Returns hash with timestamp of latest repo commit
        # and boolean signifying whether new repo has been initialized
        # in the process of pulling the data.

        newly_initialized = false
        repo = nil

        git_dir = File.join(repo_path, '.git')
        git_info_dir = File.join(git_dir, 'info')
        git_sparse_checkout_file = File.join(git_dir, 'info', 'sparse-checkout')
        unless File.exists? git_dir
          newly_initialized = true

          repo = Git.init(repo_path)

          repo.config(
            'core.sshCommand',
            'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no')

          repo.add_remote(DEFAULT_REPO_REMOTE_NAME, remote_url)

          if sparse_subtrees.size > 0
            repo.config('core.sparseCheckout', true)

            FileUtils.mkdir_p git_info_dir
            open(git_sparse_checkout_file, 'a') { |f|
              sparse_subtrees.each { |path| f << "#{path}\n" }
            }
          end

        else
          repo = Git.open(repo_path)

        end

        refresh_condition = @@siteconfig['refresh_remote_data'] || 'last-resort'
        repo_branch = branch_name || @@siteconfig['default_repo_branch'] || DEFAULT_REPO_BRANCH

        unless ['always', 'last-resort', 'skip'].include?(refresh_condition)
          raise RuntimeError.new('Invalid refresh_remote_data value in site’s _config.yml!')
        end

        if refresh_condition == 'always'
          repo.fetch(DEFAULT_REPO_REMOTE_NAME, { :depth => 1 })
          repo.reset_hard
          repo.checkout("#{DEFAULT_REPO_REMOTE_NAME}/#{repo_branch}", { :f => true })

        elsif refresh_condition == 'last-resort'
          # This is the default case.

          begin
            # Let’s try in case this repo has been fetched before (this would never be the case on CI though)
            repo.checkout("#{DEFAULT_REPO_REMOTE_NAME}/#{repo_branch}", { :f => true })
          rescue Exception => e
            if is_sparse_checkout_error(e, sparse_subtrees)
              # Silence errors caused by nonexistent sparse checkout directories
              return {
                :success => false,
                :newly_initialized => nil,
                :modified_at => nil,
              }
            else
              # In case of any other error, presume repo has not been fetched and do that now.
              Jekyll.logger.debug("OPF:", "Fetching & checking out #{remote_url} for #{repo_path}")
              repo.fetch(DEFAULT_REPO_REMOTE_NAME, { :depth => 1 })
              begin
                # Try checkout again
                repo.checkout("#{DEFAULT_REPO_REMOTE_NAME}/#{repo_branch}", { :f => true })
              rescue Exception => e
                if is_sparse_checkout_error(e, sparse_subtrees)
                  # Again, silence an error caused by nonexistent sparse checkout directories…
                  return {
                    :success => false,
                    :newly_initialized => nil,
                    :modified_at => nil,
                  }
                else
                  # but this time throw any other error.
                  raise e
                end
              end
            end
          end
        end

        latest_commit = repo.gcommit('HEAD')

        return {
          :success => true,
          :newly_initialized => newly_initialized,
          :modified_at => latest_commit.date,
        }
      end
    end

  end
end

def is_sparse_checkout_error(err, subtrees)
  if err.message.include? "Sparse checkout leaves no entry on working directory"
    Jekyll.logger.debug("OPF: It looks like sparse checkout of these directories failed:", subtrees.to_s)
    true
  else
    false
  end
end

Jekyll::Hooks.register :site, :after_init do |site|
  if site.theme  # TODO: Check theme name
    site.reader = Jekyll::OpenProjectHelpers::OpenProjectReader::new(site)
  end
end
