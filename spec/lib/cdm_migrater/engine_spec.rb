require 'rails_helper'

describe CdmMigrater::Engine do
  describe "#load_config" do
    let(:file) { File.join(fixture_path, 'cdm_migrator.yml') }
    subject { described_class.config }
    before do
      described_class.load_config(file)
    end

    it { is_expected.to eq({ "abc" => "123" })}
  end
end
