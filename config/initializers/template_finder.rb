module ActionView
  class Template
    def compile!(view)
      puts "Is (#{object_id}) compiled? #{@compiled}"
      return if @compiled

      # Templates can be used concurrently in threaded environments
      # so compilation and any instance variable modification must
      # be synchronized
      @compile_mutex.synchronize do
        # Any thread holding this lock will be compiling the template needed
        # by the threads waiting. So re-check the @compiled flag to avoid
        # re-compilation
        return if @compiled

        if view.is_a?(ActionView::CompiledTemplates)
          mod = ActionView::CompiledTemplates
        else
          mod = view.singleton_class
        end

        instrument("!compile_template") do
          compile(mod)
        end

        # Just discard the source if we have a virtual path. This
        # means we can get the template back.
        @source = nil if @virtual_path
        @compiled = true
      end
    end
  end
end

class TemplateFinder
  attr_reader :app, :root, :paths

  def initialize(app)
    @app = app
    @root = app.root
    @paths = paths
    app.reload_routes!
  end

  def templates
    route_hashes.map do |route_hash|
      name = route_hash[:action]
      prefix = route_hash[:controller]
      partial = name.start_with?("_")
      key = details_key.get(details)
      locals = []

      template = resolver.find_all(name, prefix, partial, details, key, locals)

      template.present? ? template : nil
    end.compact.flatten
  end

  def resolver
    paths.first
  end

  def routes_set
    app.routes.named_routes.routes
  end

  def route_hashes
    routes_set.keys.map do |route_name|
      route_hash = routes_set[route_name].defaults
      route_hash if route_hash.present?
    end.compact
  end

  def paths
    ActionView::PathSet.new(
      [ActionView::OptimizedFileSystemResolver.new(view_path.first)]
    )
  end

  def view_path
    Dir.glob("#{root}/app/views")
  end

  def details_key
    ActionView::LookupContext::DetailsKey
  end

  def details
    {
      :locale=>[:en],
      :formats=>[:html],
      :variants=>[],
      :handlers=>[:erb, :builder, :raw, :ruby, :coffee, :jbuilder]
    }
  end
end

finder= TemplateFinder.new(Rails.application)
view = ActionView::Base.new(finder.paths, {})
templates = finder.templates

templates.each do |template|
  template.send(:compile!, view)
end

ApplicationController.view_paths = finder.paths
