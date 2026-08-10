require 'spec_helper'

require 'scenarios/checkcodeowners'

describe Scenarios::CheckCodeOwners do
  subject(:scenario) { described_class.new }

  describe '#required_reviewers_count' do
    it 'assigns one reviewer for a regular task' do
      expect(scenario.required_reviewers_count('feature/IOS-123')).to eq(1)
    end

    it 'keeps two reviewers for an autotest task' do
      expect(scenario.required_reviewers_count('uitests/IOS-123')).to eq(2)
    end
  end
end
