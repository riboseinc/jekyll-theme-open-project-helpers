require 'digest/md5'
require 'jekyll-data/reader'
require 'git'


def is_hub(site)
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

class CollectionDocReader < Jekyll::DataReader

  def read(dir, collection)
    read_project_subdir(dir, collection)
  end

  def read_project_subdir(dir, collection, nested=false)
    return unless File.directory?(dir) && !@entry_filter.symlink?(dir)

    entries = Dir.chdir(dir) do
      Dir["*.{md,markdown,html}"] + Dir["*"].select { |fn| File.directory?(fn) }
    end

    entries.each do |entry|
      path = File.join(dir, entry)

      if File.directory?(path)
        read_project_subdir(path, collection, nested=true)
      elsif nested or (File.basename(entry, '.*') != 'index')
        doc = Jekyll::Document.new(path, :site => @site, :collection => collection)
        doc.read
        collection.docs << doc
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
    if is_hub(@site)
      fetch_and_read_projects
    else
      fetch_and_read_docs
    end
  end

  private

  def fetch_and_read_projects
    project_indexes = @site.collections['projects'].docs.select do |doc|
      pieces = doc.id.split('/')
      pieces.length == 4 and pieces[1] == 'projects' and pieces[3] == 'index'
    end
    project_indexes.each do |project|
      project_path = project.path.split('/')[0..-2].join('/')

      did_check_out = git_sparse_checkout(
        project_path,
        project['site']['git_repo_url'],
        ['_includes/', '_posts/', '_software/', '_specs/'])

      if did_check_out
        CollectionDocReader.new(site).read(
          project_path,
          @site.collections['projects'])
      end
    end
  end

  def fetch_and_read_docs

    # Software
    software_entry_points = @site.collections['software'].docs.select do |doc|
      pieces = doc.id.split('/')
      product_name = pieces[2]
      last_piece = pieces[-1]

      doc.data.key?('docs') and
      doc.data['docs']['git_repo_url'] and
      pieces[1] == 'software' and
      last_piece == product_name
    end
    software_entry_points.each do |index_doc|
      item_name = index_doc.id.split('/')[-1]
      docs_path = "#{index_doc.path.split('/')[0..-2].join('/')}/#{item_name}"

      did_check_out = git_sparse_checkout(
        docs_path,
        index_doc['docs']['git_repo_url'],
        [index_doc['docs']['git_repo_subtree']])

      if did_check_out
        CollectionDocReader.new(site).read(
          docs_path,
          @site.collections['software'])
      end
    end

    # Specs
    spec_entry_points = @site.collections['specs'].docs.select do |doc|
      pieces = doc.id.split('/')
      product_name = pieces[2]
      last_piece = pieces[-1]

      doc.data.key?('docs') and
      doc.data['docs']['git_repo_url'] and
      pieces[1] == 'specs' and
      last_piece == product_name
    end
    spec_entry_points.each do |index_doc|
      item_name = index_doc.id.split('/')[-1]
      docs_path = "#{index_doc.path.split('/')[0..-2].join('/')}/#{item_name}"

      did_check_out = git_sparse_checkout(
        docs_path,
        index_doc['docs']['git_repo_url'],
        [index_doc['docs']['git_repo_subtree']])

      if did_check_out
        CollectionDocReader.new(site).read(
          docs_path,
          @site.collections['software'])
      end
    end
  end

  def git_sparse_checkout(repo_path, remote_url, subtrees)
    # Returns boolean indicating whether the checkout happened

    git_dir = File.join(repo_path, '.git')
    unless File.exists? git_dir
      repo = Git.init(repo_path)

      repo.add_remote('origin', remote_url)

      repo.config('core.sparseCheckout', true)
      open(File.join(git_dir, 'info', 'sparse-checkout'), 'a') { |f|
        subtrees.each { |path|
          f << "#{path}\n"
        }
      }

      repo.fetch
      repo.reset_hard
      repo.checkout('origin/master', { :f => true })

      return true

    else
      return false

    end
  end
end


Jekyll::Hooks.register :site, :after_init do |site|
  if site.theme  # TODO: Check theme name
    site.reader = OpenProjectReader::new(site)
  end
end


#
# Below deals with blog and other indexes
#

module OpenProjectHelpers

  # On an open hub site, Jekyll Open Project theme assumes the existence of two types
  # of item indexes: software and specs, where items are gathered
  # from across open projects in the hub.
  #
  # The need for :item_test arises from our data structure (see Jekyll Open Project theme docs)
  # and the fact that Jekyll doesn’t intuitively handle nested collections.
  INDEXES = {
    "software" => {
      :item_test => lambda { |item| item.path.include? '/_software' and not item.path.include? '/docs' },
    },
    "specs" => {
      :item_test => lambda { |item| item.path.include? '/_specs' and not item.path.include? '/docs' },
    },
  }


  # Each software or spec item can have its tags,
  # and the theme allows to filter each index by a tag.
  # The below generates an additional index page
  # for each tag in an index, like software/Ruby.
  #
  # Note: this expects "_pages/<index page>.html" to be present in site source,
  # so it would fail if theme setup instructions were not followed fully.

  class FilteredIndexPage < Jekyll::Page
    def initialize(site, base, dir, tag, items, index_page)
      @site = site
      @base = base
      @dir = dir
      @name = 'index.html'

      self.process(@name)
      self.read_yaml(File.join(base, '_pages'), "#{index_page}.html")
      self.data['tag'] = tag
      self.data['items'] = items
    end
  end

  class FilteredIndexPageGenerator < Jekyll::Generator
    safe true

    def generate(site)
      if is_hub(site)
        INDEXES.each do |index_name, params|
          items = site.collections['projects'].docs.select { |item| params[:item_test].call(item) }

          # Creates a data structure like { tag1: [item1, item2], tag2: [item2, item3] }
          tags = {}
          items.each do |item|
            item.data['tags'].each do |tag|
              unless tags.key? tag
                tags[tag] = []
              end
              tags[tag].push(item)
            end
          end

          # Creates a filtered index page for each tag
          tags.each do |tag, tagged_items|
            site.pages << FilteredIndexPage.new(
              site,
              site.source,

              # The filtered page will be nested under /<index page>/<tag>.html
              File.join(index_name, tag),

              tag,
              tagged_items,
              index_name)
          end
        end

      end
    end
  end


  # Below passes the `items` variable to normal (unfiltered)
  # index page layout.

  class IndexPageGenerator < Jekyll::Generator
    safe true

    def generate(site)

      INDEXES.each do |index_name, params|
        if is_hub(site)
          items = site.collections['projects'].docs.select { |item| params[:item_test].call(item) }
        else
          items = site.collections[index_name].docs.select { |item| params[:item_test].call(item) }
        end

        page = site.site_payload["site"]["pages"].detect { |p| p.url == "/#{index_name}/" }
        page.data['items'] = items
      end

    end
  end


  # Below passes an array of posts of open hub blog
  # and from each individual project blog, combined and sorted by date,
  # to open hub blog index page.
  #
  # (It also does some processing on the posts.)

  class BlogIndexGenerator < Jekyll::Generator
    safe true

    def generate(site)
      site_posts = site.posts.docs

      if is_hub(site)
        # Get documents representing projects
        projects = site.collections['projects'].docs.select do |item|
          pieces = item.url.split('/')
          pieces.length == 4 && pieces[-1] == 'index' && pieces[1] == 'projects'
        end
        # Add project name (matches directory name, may differ from title)
        projects = projects.map do |project|
          project.data['name'] = project.url.split('/')[2]
          project
        end

        # Get documents representnig posts from each project’s blog
        project_posts = site.collections['projects'].docs.select { |item| item.url.include? '_posts' }

        # Add parent project’s data hash onto each
        project_posts = project_posts.map do |post|
          project_name = post.url.split('/')[2]
          post.data['parent_project'] = projects.detect { |p| p.data['name'] == project_name }
          post
        end

        posts_combined = (project_posts + site_posts).sort_by(&:date).reverse

      else
        posts_combined = site_posts

      end

      # On each post, replace authors’ emails with corresponding md5 hashes
      # suitable for hotlinking authors’ Gravatar profile pictures.
      posts_combined = posts_combined.map do |post|
        if post.data.key? 'author'
          email = post.data['author']['email']
          hash = Digest::MD5.hexdigest(email)
          post.data['author']['email'] = hash
        end
        post
      end

      blog_index = site.site_payload["site"]["pages"].detect { |page| page.url == '/blog/' }
      blog_index.data['posts_combined'] = posts_combined
    end
  end
end
