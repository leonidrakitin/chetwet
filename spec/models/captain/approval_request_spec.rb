# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Captain::ApprovalRequest, type: :model do
  describe 'associations' do
    it { is_expected.to belong_to(:account) }
    it { is_expected.to belong_to(:assistant).class_name('Captain::Assistant').optional }
    it { is_expected.to belong_to(:resolved_by).class_name('User').optional }

    it 'uses the top-level Conversation model' do
      expect(described_class.reflect_on_association(:conversation).class_name).to eq('::Conversation')
    end
  end
end
