# frozen_string_literal: true

namespace :ruby_llm do
  desc 'Refresh model registry from configured providers and save to storage/ruby_llm_models.json'
  task refresh_models: :environment do
    puts 'Refreshing models from configured providers...'
    RubyLLM.models.refresh!

    output_path = Rails.root.join('storage/ruby_llm_models.json').to_s
    RubyLLM.models.save_to_json(output_path)

    puts "Saved #{RubyLLM.models.all.size} models to #{output_path}"
    RubyLLM.models.all.group_by(&:provider).each do |provider, models|
      puts "  #{provider}: #{models.size} models"
    end
  end
end
