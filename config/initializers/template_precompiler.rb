module ActionView
  class Template
    def compile!(view)
      puts "Is (#{self.inspect}/#{object_id}) compiled? #{@compiled}"
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
  attr_reader :app, :root

  def initialize(app)
    @app = app
    @root = app.root
  end

  def resolver
    paths.first
  end

  def paths
    @paths ||= ActionView::PathSet.new(
      [ActionView::OptimizedFileSystemResolver.new(view_path)]
    )
  end

  def view_path
    Dir.glob("#{root}/app/views").first
  end

  def details_key
    ActionView::LookupContext::DetailsKey
  end

  def details
    {
      :locale=>[:en],
      :formats=>[:html],
      :variants=>[],
      :handlers=>[:raw, :erb, :html, :builder, :ruby, :coffee]
    }
  end
end

class FileTemplateFinder < TemplateFinder
  def templates
    paths = Dir.glob("#{root}/app/views/**/*.html.erb")
    paths.map do |template_path|
      name = get_name(template_path)
      prefix = get_prefix(template_path)
      partial = name.start_with?("_")
      key = details_key.get(details)
      locals = []

      name.sub!(/\_/, "") if partial

      template = resolver.find_all(name, prefix, partial, details, key, locals)

      template.present? ? template : nil
    end.compact.flatten
  end

  def get_name(template_path)
    template_path.split("/").last.split(".").first
  end

  def get_prefix(template_path)
    template_path.split("/")[-2]
  end
end

class TemplateCompiler
  attr_reader :app, :finder

  def initialize(app, finder: RouteTemplateFinder)
    @app = app
    @finder = finder.new(app)
  end

  def store_compiled_result
    ActionController::Base._view_paths = finder.paths
  end

  def compile_templates!
    templates.each do |template|
      template.send(:compile!, view)
    end
  end

  def templates
    @templates ||= finder.templates
  end

  def view
    @view ||= ActionView::Base.new(finder.paths, {})
  end
end

template_compiler = TemplateCompiler.new(Rails.application, finder: FileTemplateFinder)
template_compiler.compile_templates!
template_compiler.store_compiled_result

