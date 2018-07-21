module Jekyll
  module OpenProjectHelpers

    class CollectionDocReader < Jekyll::DataReader

      def read(dir, collection)
        read_project_subdir(dir, collection)
      end

      def read_project_subdir(dir, collection, nested=false)
        return unless File.directory?(dir) && !@entry_filter.symlink?(dir)

        entries = Dir.chdir(dir) do
          Dir["*.{md,markdown,html,svg,png}"] + Dir["*"].select { |fn| File.directory?(fn) }
        end

        entries.each do |entry|
          path = File.join(dir, entry)

          if File.directory?(path)
            read_project_subdir(path, collection, nested=true)

          elsif nested or (File.basename(entry, '.*') != 'index')
            ext = File.extname(path)
            if ['.md', '.markdown', '.html'].include? ext
              doc = Jekyll::Document.new(path, :site => @site, :collection => collection)
              doc.read
              collection.docs << doc
            else
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

      def read
        super
        if Jekyll::OpenProjectHelpers::is_hub(@site)
          fetch_and_read_projects
        else
          fetch_and_read_docs_for_items('software')
          fetch_and_read_docs_for_items('specs')
          fetch_hub_logo
        end
      end

      private

      def fetch_hub_logo
        if @site.config.key? 'parent_hub' and @site.config['parent_hub'].key? 'git_repo_url'
          git_sparse_checkout(
            File.join(@site.source, 'parent-hub'),
            @site.config['parent_hub']['git_repo_url'],
            ['assets/', 'title.html'])
        end
      end

      def fetch_and_read_projects
        project_indexes = @site.collections['projects'].docs.select do |doc|
          pieces = doc.id.split('/')
          pieces.length == 4 and pieces[1] == 'projects' and pieces[3] == 'index'
        end
        project_indexes.each do |project|
          project_path = project.path.split('/')[0..-2].join('/')

          result = git_sparse_checkout(
            project_path,
            project['site']['git_repo_url'],
            ['assets/', '_posts/', '_software/', '_specs/'])

          if result[:newly_initialized]
            CollectionDocReader.new(site).read(
              project_path,
              @site.collections['projects'])
          end

          fetch_and_read_docs_for_items('projects', 'software')
          fetch_and_read_docs_for_items('projects', 'specs')
        end
      end

      def fetch_docs_for_item(item_doc)
        item_name = item_doc.id.split('/')[-1]
        docs_path = "#{item_doc.path.split('/')[0..-2].join('/')}/#{item_name}"

        return {
          :checkout_result => git_sparse_checkout(
            docs_path,
            item_doc['docs']['git_repo_url'],
            [item_doc['docs']['git_repo_subtree']]),
          :docs_path => docs_path,
        }
      end

      def fetch_and_read_docs_for_items(collection_name, index_collection_name=nil)
        # collection_name would be either software, specs, or (for hub site) projects
        # index_collection_name would be either software or specs

        return unless @site.collections.key?(collection_name)

        index_collection_name = index_collection_name or collection_name

        entry_points = @site.collections[collection_name].docs.select do |doc|
          doc.data.key?('docs') and
          doc.data['docs']['git_repo_url']
        end
        entry_points.each do |index_doc|
          result = fetch_docs_for_item(index_doc)
          index_doc.merge_data!({ 'last_update' => result[:checkout_result][:modified_at] })
          if result[:checkout_result][:newly_initialized]
            CollectionDocReader.new(site).read(
              result[:docs_path],
              @site.collections[collection_name])
          end
        end
      end

      def git_sparse_checkout(repo_path, remote_url, subtrees)
        # Returns boolean indicating whether the checkout happened

        newly_initialized = false
        repo = nil

        git_dir = File.join(repo_path, '.git')
        unless File.exists? git_dir
          newly_initialized = true

          repo = Git.init(repo_path)

          repo.config(
            'core.sshCommand',
            'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no')

          repo.add_remote('origin', remote_url)

          repo.config('core.sparseCheckout', true)
          open(File.join(git_dir, 'info', 'sparse-checkout'), 'a') { |f|
            subtrees.each { |path| f << "#{path}\n" }
          }

        else
          repo = Git.open(repo_path)

        end

        repo.fetch
        repo.reset_hard
        repo.checkout('origin/master', { :f => true })

        latest_commit = repo.gcommit('HEAD')

        latest_commit.date

        return {
          :newly_initialized => newly_initialized,
          :modified_at => latest_commit.date,
        }
      end
    end

  end
end

Jekyll::Hooks.register :site, :after_init do |site|
  if site.theme  # TODO: Check theme name
    site.reader = Jekyll::OpenProjectHelpers::OpenProjectReader::new(site)
  end
end
