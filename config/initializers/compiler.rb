class TemplateCompiler
  attr_reader :root, :paths

  def initialize(app)
    @root = app.root
    @view_path = Dir.glob("#{root}/app/views")
    @paths = ActionView::PathSet.new(
      [ActionView::OptimizedFileSystemResolver.new(@view_path.first)]
    )
  end

  def template_paths
    Dir.glob("#{root}/app/views/**/*.html.erb")
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

  def get_name(template_path)
    template_path.split("/").last.split(".").first
  end

  def get_prefix(template_path)
    template_path.split("/")[-2]
  end
end

compiler = TemplateCompiler.new(Rails.application)
resolver = compiler.paths.first
templates = compiler.template_paths.map do |template_path|
  name = compiler.get_name(template_path)
  prefix = compiler.get_prefix(template_path)
  partial = name.start_with?("_")
  details = compiler.details
  key = compiler.details_key.get(details)
  locals = []

  template = resolver.find_all(name, prefix, partial, details, key, locals)

  template.present? ? template : nil
end.compact.flatten


view = ActionView::Base.new(compiler.paths, {})

templates.each do |template|
  template.send(:compile!, view)
end

ApplicationController.view_paths = compiler.paths
