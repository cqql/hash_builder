module HashBuilder
  # Renders templates with '.json_builder' extension.
  #
  # If the template is a normal view, it will render a JSON string.
  # If the template however is a partial, it renders a Hash so that
  # json_builder files can use partials.
  class Template
    def self.default_format
      Mime::JSON
    end

    def self.call (template)
      # The template is on the first line, so that line numbers in the
      # error stacks are correct.
      render_code = <<-RUBY
hash = HashBuilder.build(scope: self, locals: local_assigns) do #{template.source} end

if hash.size == 1 && hash.keys == [:array]
  hash = hash[:array]
end


RUBY

      if !is_partial?(template)
        # ActiveModel defines #as_json in a way, that is not compatible
        # with JSON.
        if defined?(ActiveModel)
          render_code += "ActiveSupport::JSON.encode(hash)"
        else
          render_code += "JSON.generate(hash)"
        end
      else
        render_code += "hash"
      end
      
      render_code
    end

    def self.is_partial? (template)
      template.virtual_path.split("/").last.start_with?("_")
    end
  end
end

if defined?(ActionView)
  ActionView::Template.register_template_handler :json_builder, HashBuilder::Template
end
