# frozen_string_literal: true

require "spec_helper"
require "non-digest-assets"
require "tmpdir"
require "fileutils"

RSpec.describe NonDigestAssets::CompileWithNonDigest, type: :aruba do
  let(:sprockets) do
    klass = Class.new do
      attr_reader :dir

      def initialize
        @dir = Dir.pwd
      end

      def compile
        files = ["#{dir}/foo-deadbeef.css", "#{dir}/bar-f00df00d.css"]
        files.each { |it| make_asset it }
      end

      def assets
        [["foo.css", "foo-deadbeef.css"],
         ["bar.css", "bar-f00df00d.css"]]
      end

      def logger
        @logger ||= Logger.new(StringIO.new)
      end

      private

      def make_asset(asset)
        FileUtils.touch asset
      end
    end
    klass.prepend described_class
    in_current_directory do
      klass.new
    end
  end

  before do
    NonDigestAssets.selected_assets = []
  end

  describe "#compile" do
    it "returns the result of the super method" do
      result = sprockets.compile
      expect(result).to eq [expand_path("foo-deadbeef.css"),
                            expand_path("bar-f00df00d.css")]
    end

    describe "if regular files for each asset exist but gzipped files do not" do
      it "creates only non-digest versions for each asset" do
        sprockets.compile
        aggregate_failures do
          expect("foo.css").to be_an_existing_file
          expect("bar.css").to be_an_existing_file
          expect("foo.css.gz").not_to be_an_existing_file
          expect("bar.css.gz").not_to be_an_existing_file
        end
      end

      it "does not copy files for non-selected assets" do
        NonDigestAssets.selected_assets = ["bar.css"]
        sprockets.compile
        aggregate_failures do
          expect("foo.css").not_to be_an_existing_file
          expect("bar.css").to be_an_existing_file
        end
      end
    end

    describe "if no files exist for each asset" do
      before do
        sprockets.define_singleton_method :make_asset do |it|
          # Do nothing
        end
      end

      it "does not create any non-digest versions for each asset" do
        sprockets.compile
        aggregate_failures do
          expect("foo.css").not_to be_an_existing_file
          expect("bar.css").not_to be_an_existing_file
          expect("foo.css.gz").not_to be_an_existing_file
          expect("bar.css.gz").not_to be_an_existing_file
        end
      end
    end

    describe "if both regular and gzipped files exist for each asset" do
      before do
        sprockets.define_singleton_method :make_asset do |it|
          FileUtils.touch it
          FileUtils.touch "#{it}.gz"
        end
      end

      it "creates both regular and gzipped non-digest versions for each asset" do
        sprockets.compile
        aggregate_failures do
          expect("foo.css").to be_an_existing_file
          expect("bar.css").to be_an_existing_file
          expect("foo.css.gz").to be_an_existing_file
          expect("bar.css.gz").to be_an_existing_file
        end
      end

      it "does not copy files for non-selected assets" do
        NonDigestAssets.selected_assets = ["bar.css"]
        sprockets.compile
        aggregate_failures do
          expect("foo.css").not_to be_an_existing_file
          expect("bar.css").to be_an_existing_file
          expect("foo.css.gz").not_to be_an_existing_file
          expect("bar.css.gz").to be_an_existing_file
        end
      end
    end
  end
end
