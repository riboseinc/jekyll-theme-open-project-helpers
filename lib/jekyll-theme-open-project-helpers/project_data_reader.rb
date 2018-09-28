require 'fileutils'

module Jekyll
  module OpenProjectHelpers

    DEFAULT_DOCS_SUBTREE = 'docs'

    DEFAULT_REPO_REMOTE_NAME = 'origin'
    DEFAULT_REPO_BRANCH = 'master'

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

          if File.directory?(path)
            read_project_subdir(path, collection, nested=true)

          elsif nested or (File.basename(entry, '.*') != 'index')
            ext = File.extname(path)
            if ['.adoc', '.md', '.markdown', '.html'].include? ext
              doc = NonLiquidDocument.new(path, :site => @site, :collection => collection)
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
        if @site.config['is_hub']
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
          git_shallow_checkout(
            File.join(@site.source, 'parent-hub'),
            @site.config['parent_hub']['git_repo_url'],
            ['assets', 'title.html'])
        end
      end

      def fetch_and_read_projects
        project_indexes = @site.collections['projects'].docs.select do |doc|
          pieces = doc.id.split('/')
          pieces.length == 4 and pieces[1] == 'projects' and pieces[3] == 'index'
        end
        project_indexes.each do |project|
          project_path = project.path.split('/')[0..-2].join('/')

          result = git_shallow_checkout(
            project_path,
            project['site']['git_repo_url'],
            ['assets', '_posts', '_software', '_specs'])

          if result[:newly_initialized]
            CollectionDocReader.new(site).read(
              project_path,
              @site.collections['projects'])
          end

          fetch_and_read_docs_for_items('projects', 'software')
          fetch_and_read_docs_for_items('projects', 'specs')
        end
      end

      def fetch_and_read_docs_for_items(collection_name, index_collection_name=nil)
        # collection_name would be either software, specs, or (for hub site) projects
        # index_collection_name would be either software, specs or (for project site) nil

        return unless @site.collections.key?(collection_name)

        index_collection_name = index_collection_name or collection_name

        entry_points = @site.collections[collection_name].docs.select do |doc|
          doc.data['repo_url']
        end

        entry_points.each do |index_doc|
          item_name = index_doc.id.split('/')[-1]

          if index_doc.data.key?('docs') and index_doc.data['docs']['git_repo_url']
            docs_repo = index_doc.data['docs']['git_repo_url']
            docs_subtree = index_doc.data['docs']['git_repo_subtree'] || DEFAULT_DOCS_SUBTREE
          else
            docs_repo = index_doc.data['repo_url']
            docs_subtree = DEFAULT_DOCS_SUBTREE
          end

          docs_path = "#{index_doc.path.split('/')[0..-2].join('/')}/#{item_name}"

          begin
            docs_checkout = git_shallow_checkout(docs_path, docs_repo, [docs_subtree])

            CollectionDocReader.new(site).read(
              docs_checkout[:docs_path],
              @site.collections[collection_name])

          rescue
            docs_checkout = nil

          end

          # Get last repository modification timestamp.
          # Fetch the repository for that purpose,
          # unless it’s the same as the repo where docs are.
          if docs_checkout == nil or docs_repo != index_doc.data['repo_url']
            repo_path = "#{index_doc.path.split('/')[0..-2].join('/')}/_#{item_name}_repo"
            repo_checkout = git_shallow_checkout(repo_path, index_doc.data['repo_url'])
            index_doc.merge_data!({ 'last_update' => repo_checkout[:modified_at] })
          else
            index_doc.merge_data!({ 'last_update' => docs_checkout[:modified_at] })
          end
        end
      end

      def git_shallow_checkout(repo_path, remote_url, sparse_subtrees=[])
        # Returns hash with timestamp of latest repo commit
        # and boolean signifying whether new repo has been initialized
        # in the process of pulling the data.

        newly_initialized = false
        repo = nil

        git_dir = File.join(repo_path, '.git')
        unless File.exists? git_dir
          newly_initialized = true

          repo = Git.init(repo_path)

          repo.config(
            'core.sshCommand',
            'ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no')

          repo.add_remote(DEFAULT_REPO_REMOTE_NAME, remote_url)

          if sparse_subtrees.size > 0
            repo.config('core.sparseCheckout', true)

            FileUtils.mkdir_p File.join(git_dir, 'info')
            open(File.join(git_dir, 'info', 'sparse-checkout'), 'a') { |f|
              sparse_subtrees.each { |path| f << "#{path}\n" }
            }
          end

        else
          repo = Git.open(repo_path)

        end

        repo.fetch(DEFAULT_REPO_REMOTE_NAME, { :depth => 1 })
        repo.reset_hard
        repo.checkout('#{DEFAULT_REPO_REMOTE_NAME}/#{DEFAULT_REPO_BRANCH}', { :f => true })

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
