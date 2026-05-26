module SlashMigrate
  class ModelsController < ApplicationController
    def new
      @generator = ModelGenerator.new(name: "")
    end

    # Live preview: re-runs on every (debounced) form change and streams the
    # generated migration + model back into the preview pane. Generation runs in
    # a temp dir, so nothing is written until the student explicitly creates.
    def preview
      @generator = build_generator
      @hint = "Enter a model name to see the migration it will generate." if @generator.name.blank?
      @files = @generator.preview if @generator.name.present?
      render :preview, layout: false
    rescue => e
      # Partial/invalid input shouldn't 500 the live preview; show the problem.
      @error = e.message
      render :preview, layout: false
    end

    def create
      generator = build_generator
      @files = generator.create!
      redirect_to new_model_path,
        notice: "Created #{@files.map(&:relative_path).join(", ")}. Run the migration to apply it."
    end

    private

    def build_generator
      ModelGenerator.from_params(name: params[:model_name], attributes: attribute_params)
    end

    def attribute_params
      Array(params[:attributes]).map do |attr|
        {name: attr[:name], type: attr[:type], index: attr[:index]}
      end
    end
  end
end
