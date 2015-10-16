require 'spec_helper'

module Flatter::Extensions
  ::Flatter.use :skipping

  module SkippingSpec
    class A
      include ActiveModel::Model

      attr_accessor :a1

      def b
        @b ||= B.new
      end

      def cs
        @cs ||= Array.new(3){ C.new(c: 'c') }
      end
    end

    class B
      include ActiveModel::Model

      def save
        true
      end
    end

    class C
      include ActiveModel::Model

      attr_accessor :c

      def save
        c << '-saved'
      end
    end

    class AMapper < ::Flatter::Mapper
      map :a1
      mount :b

      set_callback :save, :before, -> { mounting(:b).skip! if a1 == 'skip!' }

      trait :with_collection do
        mount :cs

        set_callback :save, :before, -> { mounting(:cs).skip! }
      end
    end

    class BMapper < ::Flatter::Mapper
    end

    class CMapper < ::Flatter::Mapper
      map attr_c: :c
    end
  end

  RSpec.describe Skipping do
    let(:model)  { SkippingSpec::A.new }
    let(:mapper) { SkippingSpec::AMapper.new(model) }

    specify 'when conditions are met' do
      mapper.write(a1: 'skip!')
      expect_any_instance_of(SkippingSpec::B).not_to receive(:save)
      mapper.save
      expect(mapper.mounting(:b)).to be_skipped
    end

    specify 'when conditions are not met' do
      mapper.write(a1: 'a1')
      expect_any_instance_of(SkippingSpec::B).to receive(:save)
      mapper.save
    end

    describe "collections support" do
      let(:mapper) { SkippingSpec::AMapper.new(model, :with_collection) }

      it "does not save items" do
        mapper.save
        expect(mapper.attr_cs).to eq %w(c c c)
      end
    end
  end
end
